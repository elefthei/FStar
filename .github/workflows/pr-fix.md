---
emoji: "🛠️"
name: PR Fix
description: |
  Fixes pull requests on demand with the /pr-fix command. Addresses review
  comments (e.g. from the PR Code Quality Reviewer) and failing CI checks,
  builds/tests F*, and pushes the fixes to the PR branch. Any text after
  /pr-fix is treated as extra instructions.
on:
  roles: [admin, maintainer, write]
  slash_command:
    name: pr-fix
    strategy: centralized
    events: [pull_request_comment, pull_request_review_comment]
  reaction: eyes
  status-comment: true
concurrency:
  job-discriminator: ${{ github.run_id }}
permissions:
  contents: read
  issues: read
  pull-requests: read
  actions: read
  checks: read
engine:
  id: copilot
  copilot-sdk: true
  model: claude-opus-5.5
imports:
  - shared/reporting.md
  - shared/fstar-build-env.md
tools:
  cli-proxy: true
  web-fetch:
  edit:
  bash: true
  github:
    mode: gh-proxy
    toolsets: [default, actions]
    min-integrity: none # invoked explicitly by a maintainer
safe-outputs:
  push-to-pull-request-branch:
    if-no-changes: "ignore"
  create-issue:
    title-prefix: "[pr-fix] "
    labels: [automation, pr-fix]
  add-comment:
    max: 1
  messages:
    footer: "> 🛠️ *Fixed by [{workflow_name}]({run_url})*{ai_credits_suffix}{history_link}"
    run-started: "🛠️ [{workflow_name}]({run_url}) is working on this {event_type}..."
    run-success: "✅ [{workflow_name}]({run_url}) finished."
    run-failure: "⚠️ [{workflow_name}]({run_url}) {status}."
timeout-minutes: 120
strict: true
---

# PR Fix

You are an expert F* (FStar) compiler engineer. Your job is to push fixes to
pull request #${{ github.event.issue.number || github.event.pull_request.number }}
in ${{ github.repository }}.

## Instructions from the maintainer

"${{ steps.sanitized.outputs.text }}"

If there are no specific instructions beyond `/pr-fix`, your job is to:

1. Address all **unresolved review comments** on the PR (in particular those
   from the *PR Code Quality Reviewer* workflow and from human reviewers).
2. Fix any **failing CI checks** for the PR's head commit.

## Process

1. Read the PR title/body, the diff, the review threads and the comments:
   - `gh pr view <number> --repo ${{ github.repository }} --json title,body,headRefName,baseRefName,files --jq '{title, headRefName, baseRefName, body: .body[0:4000], files: [.files[].path]}'`
   - `gh api repos/${{ github.repository }}/pulls/<number>/comments --paginate --jq '.[] | {id, path, line: (.line // .original_line), user: .user.login, body: .body[0:1500]}'`
   - `gh api repos/${{ github.repository }}/pulls/<number>/reviews --jq '.[] | {user: .user.login, state, body: .body[0:2000]}'`
2. If CI is failing, find the failed runs for the head SHA and read the failed
   job logs (GitHub `actions` tools, or `gh run list` / `gh run view --log-failed`).
   Identify the root cause from the actual error messages.
3. Check out the PR branch (`gh pr checkout <number>` or `git fetch origin <headRefName> && git checkout <headRefName>`).
4. Plan the changes, then implement them. Keep changes minimal and focused on
   the review comments / CI failures; do not refactor unrelated code.
   Use your judgement: if a review comment is wrong, don't apply it — explain why
   in your summary comment instead.
5. Build and test with the narrowest make target that validates your change
   (see the F* build environment notes below). Iterate until it passes.
6. If you made progress, push the changes to the PR branch with the
   `push-to-pull-request-branch` safe output.
7. Add one comment on the PR summarising, per review comment / CI failure, what
   you changed (or why you didn't), and what you built/tested. Use the
   `reporting` skill; keep it short and put details in `<details>` blocks.
   End with: "Comment `/review` to get a fresh review."

Do not edit `.github/workflows/*` and do not refresh the `stage0/` snapshot
unless explicitly asked to. If the fix is out of scope for this PR, open an
issue with `create-issue` instead and mention it in your comment.
