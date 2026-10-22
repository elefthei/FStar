---
emoji: "📊"
name: Weekly Repo Status
description: |
  Weekly repository status report as a GitHub issue: recent issues, PRs, CI
  health and agentic workflow activity, with recommended next steps.
on:
  schedule: weekly on monday
  workflow_dispatch:
permissions:
  contents: read
  issues: read
  pull-requests: read
  actions: read
engine: copilot
strict: true
network: defaults
imports:
  - shared/reporting.md
tools:
  cli-proxy: true
  bash: ["cat", "ls", "find", "grep", "head", "tail", "wc", "git log", "git shortlog"]
  github:
    mode: gh-proxy
    toolsets: [default, actions]
    min-integrity: none # summarises issues and PRs from any author
safe-outputs:
  mentions: false
  allowed-github-references: []
  create-issue:
    title-prefix: "[repo-status] "
    labels: [report, repo-status]
    close-older-issues: true
timeout-minutes: 15
---

# Weekly Repo Status 📊

Create a concise weekly status report for ${{ github.repository }} (F*) as a
GitHub issue, covering the last 7 days.

## What to include

- **Activity**: issues opened/closed, PRs opened/merged, notable commits
  (`git log --since="7 days ago"`), releases.
- **CI health**: recent runs of the `CI` and `Nightly CI` workflows — failures,
  flaky jobs, and any open `[CI failure]` issues.
- **Agent activity**: PRs and issues created by the agentic workflows (labels
  `scout`, `pr-fix`, `plan`, `automation`), and which still need attention
  (e.g. Scout PRs with requested changes — suggest `/pr-fix`; issues that look
  ready to pick up — suggest `/scout`).
- **Recommendations**: 3–5 actionable next steps for maintainers.

## Style

- Use the `reporting` skill: overview first, details in `<details>` blocks.
- Be concise; scale length to the actual activity. Use emojis sparingly.
- If there was no activity at all, use `noop` instead of creating an issue.
