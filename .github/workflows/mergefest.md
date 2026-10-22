---
emoji: "🔀"
name: Mergefest
description: Merges the base branch into a pull request branch (resolving conflicts) when invoked with the /mergefest command
on:
  roles: [admin, maintainer, write]
  slash_command:
    strategy: centralized
    name: mergefest
    events: [pull_request_comment]
  reaction: eyes
  status-comment: true
concurrency:
  job-discriminator: ${{ github.run_id }}
permissions:
  contents: read
  pull-requests: read
  actions: read
engine:
  id: copilot
  copilot-sdk: true
max-tool-denials: 3
imports:
  - shared/fstar-build-env.md
checkout:
  fetch-depth: 0
  submodules: true
tools:
  cli-proxy: true
  bash: true
  edit:
  github:
    mode: gh-proxy
    toolsets: [pull_requests, repos]
safe-outputs:
  push-to-pull-request-branch:
    if-no-changes: "ignore"
  add-comment:
    max: 1
  messages:
    footer: "> 🔀 *Merged by [{workflow_name}]({run_url})*{ai_credits_suffix}{history_link}"
timeout-minutes: 60
strict: true
---

# Mergefest 🔀

You merge the base branch into the branch of pull request
#${{ github.event.issue.number || github.event.pull_request.number }} in
${{ github.repository }}, resolving conflicts carefully.

Extra instructions from the maintainer (may be empty): "${{ steps.sanitized.outputs.text }}"

## Steps

1. Get the PR details (`gh pr view <number> --json state,headRefName,baseRefName,mergeable`).
   Stop with a comment if the PR is not open.
2. Check out the PR branch and fetch the base branch:
   `git fetch origin <baseRefName> <headRefName> && git checkout <headRefName>`.
3. Merge: `git merge --no-ff origin/<baseRefName>`.
   - If it merges cleanly, continue.
   - If there are conflicts, resolve each one by understanding both sides
     (`git log`/`git show` on the relevant commits). Rules for F*:
     - `stage0/` (extracted OCaml snapshot) and `*.hints` files: take the
       base branch version (`git checkout --theirs -- <path>`); they are
       regenerated, never hand-merged.
     - `.github/workflows/*.lock.yml`: take the base branch version.
     - `CHANGES.md`: keep both entries.
     - Source files (`src/`, `ulib/`, `pulse/`, `tests/`): merge both
       intents; never silently drop changes from either side.
   - If a conflict cannot be resolved confidently, abort (`git merge --abort`)
     and explain the conflicting files and why in a comment instead.
4. Sanity check: if F* source files were touched by conflict resolution,
   build with `make -skj$(nproc) 2` (see the build environment notes) and fix
   anything your resolution broke. Do not run the full test suite.
5. Push the result with the `push-to-pull-request-branch` safe output. Do not
   rewrite history (no rebase, no force-push).
6. Add one short comment summarising: the merged base commit, conflicts and
   how each was resolved, and what was built.
