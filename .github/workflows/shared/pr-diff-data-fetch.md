---
# Shared pre-agent-steps for pre-fetching PR diff, metadata, and review comments.
# Works for both pull_request events and slash_command (issue) events on PRs.
#
# Outputs written to:
#   /tmp/gh-aw/agent/pr-diff.patch          — unified diff of non-generated files (up to 2000 lines)
#   /tmp/gh-aw/agent/pr-meta.json           — PR metadata (number, title, body, etc.)
#   /tmp/gh-aw/agent/pr-review-comments.json — existing inline review comments
#
# Skip-check: if cached diff and file metadata match the PR number and head SHA,
# they are reused. Mutable metadata and review comments are always refreshed.
#
# Usage:
#   cache:
#     key: pr-prefetch-v2-${{ github.event.pull_request.number || github.event.issue.number || (fromJSON(github.event.inputs.aw_context || github.event.client_payload.aw_context || '{}').item_type == 'pull_request' && fromJSON(github.event.inputs.aw_context || github.event.client_payload.aw_context || '{}').item_number) }}-${{ github.event.pull_request.head.sha || 'unknown' }}-${{ github.run_id }}-${{ github.run_attempt }}
#     path: /tmp/gh-aw/agent
#     restore-keys:
#       - pr-prefetch-v2-${{ github.event.pull_request.number || github.event.issue.number || (fromJSON(github.event.inputs.aw_context || github.event.client_payload.aw_context || '{}').item_type == 'pull_request' && fromJSON(github.event.inputs.aw_context || github.event.client_payload.aw_context || '{}').item_number) }}-${{ github.event.pull_request.head.sha && format('{0}-', github.event.pull_request.head.sha) || '' }}
#   imports:
#     - uses: shared/pr-diff-data-fetch.md
#       with:
#         max-diff-lines: "2000"  # optional; defaults to 2000

import-schema:
  max-diff-lines:
    type: string
    default: "2000"
    description: "Maximum number of PR diff lines to pre-fetch"

pre-agent-steps:
  - name: Pre-fetch PR diff and review comments
    env:
      GH_TOKEN: ${{ github.token }}
      PR_NUMBER: ${{ github.event.issue.number || github.event.pull_request.number || (fromJSON(github.event.inputs.aw_context || github.event.client_payload.aw_context || '{}').item_type == 'pull_request' && fromJSON(github.event.inputs.aw_context || github.event.client_payload.aw_context || '{}').item_number) }}
      PR_HEAD_SHA: ${{ github.event.pull_request.head.sha }}
      EXPR_GITHUB_REPOSITORY: ${{ github.repository }}
      PR_DIFF_MAX_LINES: ${{ github.aw.import-inputs.max-diff-lines }}
    run: |
      set -euo pipefail
      mkdir -p /tmp/gh-aw/agent
      if [ -z "$PR_NUMBER" ]; then
        echo "::error::Unable to determine the pull request number from the event context." >&2
        exit 1
      fi
      fetch_review_comments() {
        local tmp=/tmp/gh-aw/agent/pr-review-comments.json.tmp
        if gh api "repos/$EXPR_GITHUB_REPOSITORY/pulls/$PR_NUMBER/comments?per_page=100" \
            --paginate \
            --jq '.[] | {id, path, line: (.line // .original_line), body: .body[:200], user: .user.login}' \
            | jq -s '.' > "$tmp"; then
          mv "$tmp" /tmp/gh-aw/agent/pr-review-comments.json
        else
          rm -f "$tmp"
          echo "::warning::Failed to fetch existing review comments for PR #${PR_NUMBER}; continuing with an empty list (duplicate comments are possible)." >&2
          echo '[]' > /tmp/gh-aw/agent/pr-review-comments.json
        fi
      }
      CURRENT_HEAD_SHA="${PR_HEAD_SHA:-}"
      if [ -z "$CURRENT_HEAD_SHA" ]; then
        CURRENT_HEAD_SHA=$(gh pr view "$PR_NUMBER" --repo "$EXPR_GITHUB_REPOSITORY" --json headRefOid --jq '.headRefOid' 2>/dev/null || true)
      fi
      CACHE_HEAD_SHA=""
      if [ -f /tmp/gh-aw/agent/pr-data-head-sha.txt ]; then
        CACHE_HEAD_SHA="$(tr -d '\n' < /tmp/gh-aw/agent/pr-data-head-sha.txt)"
      fi
      fetch_review_comments
      # Skip diff fetch only when cache data matches the current PR and head commit.
      if [ -n "$CURRENT_HEAD_SHA" ] && [ "$CURRENT_HEAD_SHA" = "$CACHE_HEAD_SHA" ] && \
        [ -f /tmp/gh-aw/agent/pr-diff.patch ] && \
        jq -e --arg sha "$CURRENT_HEAD_SHA" --argjson number "$PR_NUMBER" \
          '.headRefOid == $sha and .number == $number and (.files | type == "array")' \
          /tmp/gh-aw/agent/pr-meta.json >/dev/null 2>&1; then
        if [ -n "$PR_HEAD_SHA" ]; then
          jq '.pull_request | {number, title, body, headRefName: .head.ref,
            headRefOid: .head.sha, additions, deletions, changedFiles: .changed_files}' \
            "$GITHUB_EVENT_PATH" > /tmp/gh-aw/agent/pr-meta.json.tmp
        else
          gh pr view "$PR_NUMBER" --repo "$EXPR_GITHUB_REPOSITORY" \
            --json number,title,body,headRefName,headRefOid,additions,deletions,changedFiles \
            > /tmp/gh-aw/agent/pr-meta.json.tmp
        fi
        if ! jq -e --arg sha "$CURRENT_HEAD_SHA" --argjson number "$PR_NUMBER" \
          --slurpfile metadata /tmp/gh-aw/agent/pr-meta.json.tmp \
          '.files as $files | $metadata[0] | select(.number == $number and .headRefOid == $sha) |
            . + {files: $files}' \
          /tmp/gh-aw/agent/pr-meta.json > /tmp/gh-aw/agent/pr-meta.refreshed.json; then
          echo "::error::Failed to refresh metadata for PR #${PR_NUMBER} at head ${CURRENT_HEAD_SHA}" >&2
          exit 1
        fi
        mv /tmp/gh-aw/agent/pr-meta.refreshed.json /tmp/gh-aw/agent/pr-meta.json
        rm -f /tmp/gh-aw/agent/pr-meta.json.tmp
        LINES=$(wc -l < /tmp/gh-aw/agent/pr-diff.patch)
        COMMENT_COUNT=$(jq 'length' /tmp/gh-aw/agent/pr-review-comments.json)
        echo "Cache hit: using pre-fetched PR data for head ${CURRENT_HEAD_SHA} (${LINES} diff lines, ${COMMENT_COUNT} review comments)"
      else
        # The whole-PR diff endpoint rejects PRs with more than 300 files, even
        # when gh pr diff --exclude would discard most of them afterward.
        # Exclude F* generated/snapshot paths (stage0 OCaml snapshot, hints, lock files).
        if ! gh api --paginate "repos/$EXPR_GITHUB_REPOSITORY/pulls/$PR_NUMBER/files?per_page=100" \
          --jq '.[] | select(.filename | test("^stage0/|(^|/)generated/|\\.hints$|\\.lock\\.yml$") | not) | select(.patch != null) | "diff --git a/\(.previous_filename // .filename) b/\(.filename)\n" + (if .status == "added" then "new file mode 100644\n--- /dev/null\n+++ b/\(.filename)\n" elif .status == "removed" then "deleted file mode 100644\n--- a/\(.filename)\n+++ /dev/null\n" else "--- a/\(.previous_filename // .filename)\n+++ b/\(.filename)\n" end) + .patch + "\n"' \
          > /tmp/gh-aw/agent/pr-diff.full 2> /tmp/gh-aw/agent/pr-diff.err; then
          echo "::error::Failed to fetch files for PR #${PR_NUMBER}: $(cat /tmp/gh-aw/agent/pr-diff.err)" >&2
          rm -f /tmp/gh-aw/agent/pr-diff.full /tmp/gh-aw/agent/pr-diff.err
          exit 1
        fi
        head -n "${PR_DIFF_MAX_LINES}" /tmp/gh-aw/agent/pr-diff.full > /tmp/gh-aw/agent/pr-diff.patch
        rm -f /tmp/gh-aw/agent/pr-diff.full /tmp/gh-aw/agent/pr-diff.err
        LINES=$(wc -l < /tmp/gh-aw/agent/pr-diff.patch)
        gh pr view "$PR_NUMBER" \
          --repo "$EXPR_GITHUB_REPOSITORY" \
          --json number,title,body,headRefName,headRefOid,additions,deletions,changedFiles,files \
          > /tmp/gh-aw/agent/pr-meta.json
        if [ -z "$CURRENT_HEAD_SHA" ]; then
          CURRENT_HEAD_SHA="$(jq -r '.headRefOid // empty' /tmp/gh-aw/agent/pr-meta.json)"
        fi
        if [ -n "$CURRENT_HEAD_SHA" ]; then
          printf '%s\n' "$CURRENT_HEAD_SHA" > /tmp/gh-aw/agent/pr-data-head-sha.txt
        else
          rm -f /tmp/gh-aw/agent/pr-data-head-sha.txt
        fi
        COMMENT_COUNT=$(jq 'length' /tmp/gh-aw/agent/pr-review-comments.json)
        echo "Pre-fetched PR diff (${LINES} lines), metadata, and ${COMMENT_COUNT} existing review comments for head ${CURRENT_HEAD_SHA:-unknown}"
      fi
---

<!--
## PR Diff Data Fetch

Shared pre-agent-steps component used by PR reviewer workflows to pre-fetch PR
diff, metadata, and inline review comments before the agent starts.

### Output files

| File | Content |
|---|---|
| `/tmp/gh-aw/agent/pr-diff.patch` | Unified diff (stage0/, generated/, *.hints and *.lock.yml excluded, capped at `max-diff-lines`, default 2000) |
| `/tmp/gh-aw/agent/pr-meta.json` | `number, title, body, headRefName, additions, deletions, changedFiles, files` |
| `/tmp/gh-aw/agent/pr-review-comments.json` | Array of `{id, path, line, body, user}` (body capped at 200 chars) |
-->
