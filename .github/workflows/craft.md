---
emoji: "✍️"
name: Craft
description: Generates a new agentic workflow (.md) from a natural-language request when invoked with /craft on an issue, and opens a pull request
on:
  roles: [admin, maintainer, write]
  slash_command:
    strategy: centralized
    name: craft
    events: [issues, issue_comment]
  reaction: eyes
  status-comment: true
concurrency:
  job-discriminator: ${{ github.run_id }}
permissions:
  contents: read
  issues: read
  pull-requests: read
  actions: read
engine:
  id: copilot
  copilot-sdk: true
max-tool-denials: 3
imports:
  - shared/reporting.md
tools:
  cli-proxy: true
  edit:
  bash: true
  agentic-workflows:
  github:
    mode: gh-proxy
    toolsets: [default]
steps:
  - name: Fetch the gh-aw workflow authoring reference
    run: |
      set -eu
      mkdir -p /tmp/gh-aw/agent
      curl -fsSL "https://raw.githubusercontent.com/github/gh-aw/v0.92.0/.github/aw/github-agentic-workflows.md" \
        -o /tmp/gh-aw/agent/github-agentic-workflows.md
timeout-minutes: 20
safe-outputs:
  create-pull-request:
    title-prefix: "[craft] "
    labels: [automation, agentic-workflows]
    draft: false
    if-no-changes: "ignore"
    protected-files: request-review # new workflows live in .github/workflows/
    excluded-files:
      - ".github/workflows/*.lock.yml"
  add-comment:
    max: 1
  messages:
    footer: "> ⚒️ *Crafted with care by [{workflow_name}]({run_url})*{ai_credits_suffix}{history_link}"
    run-started: "🛠️ Master Crafter at work! [{workflow_name}]({run_url}) is forging a new workflow on this {event_type}..."
    run-success: "⚒️ Masterpiece complete! [{workflow_name}]({run_url}) has crafted your workflow. 🎖️"
    run-failure: "🛠️ Forge cooling down! [{workflow_name}]({run_url}) {status}. The anvil awaits another attempt..."
---

# Workflow Craft Agent

You are an expert workflow designer for GitHub Agentic Workflows (gh-aw). Your
task is to generate a new agentic workflow for ${{ github.repository }} (the F*
proof-oriented programming language) based on the user's request.

## Current Context

- **Repository**: ${{ github.repository }}
- **Issue**: #${{ github.event.issue.number }}
- **Request**:

<request>
${{ steps.sanitized.outputs.text }}
</request>

If the request text is just `/craft`, use the issue title and body as the request.

## Process

1. **Load the reference**: read `/tmp/gh-aw/agent/github-agentic-workflows.md`
   (the gh-aw workflow format specification: frontmatter schema, triggers,
   permissions, tools, safe outputs, best practices). You can also use the
   `agentic-workflows` MCP server tools.
2. **Learn local conventions**: read `.github/AGENTIC_WORKFLOWS.md` and
   look at the existing workflows (`.github/workflows/*.md`) and shared imports
   (`.github/workflows/shared/`). Reuse shared imports where they fit, e.g.
   `shared/fstar-build-env.md` for workflows that need to build F*, and
   `shared/reporting.md` for report formatting.
3. **Design** the workflow:
   - `on:` appropriate trigger(s). Prefer `slash_command` with
     `strategy: centralized` for on-demand commands.
   - minimal read-only `permissions:`; all writes go through `safe-outputs:`.
   - `engine: copilot` unless the request needs something else.
   - only the `tools:` actually needed; a reasonable `timeout-minutes:`;
     `strict: true`.
   - a clear prompt: mission, context (only allowed GitHub expressions),
     step-by-step instructions, guidelines and output format.
4. **Create** `.github/workflows/<kebab-case-name>.md` with the `edit` tool.
5. **Validate** with the `compile` tool of the `agentic-workflows` MCP server
   and fix all errors (and warnings where reasonable). Do not commit the
   generated `.lock.yml` file; only the `.md` source (and any new shared
   import) goes into the pull request.
6. **Open a pull request** with the `create-pull-request` safe output. In the
   body, describe what the workflow does, how to trigger it, required secrets
   (if any), and note that the `.lock.yml` must be generated with
   `gh aw compile` before merging (e.g. ask `@copilot` on the PR to run
   `gh aw compile` and commit the lock file).
7. **Comment** on the issue with the PR link, a one-paragraph description and
   how to trigger the workflow.
