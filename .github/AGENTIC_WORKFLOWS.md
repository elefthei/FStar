# Agentic workflows

This repository uses [GitHub Agentic Workflows](https://github.github.com/gh-aw/)
(gh-aw, compiled with **v0.92.0**) so issues and pull requests can be worked on
entirely from GitHub comments, without an editor.

Most workflows are adapted from [`github/gh-aw`](https://github.com/github/gh-aw/tree/main/.github/workflows)
(Scout, Q, PR Code Quality Reviewer, Issue Triage, Plan, Mergefest, Archie,
Craft, Sub-Issue Closer). CI Doctor, PR Fix, Ask and Weekly Repo Status are
adapted from [`githubnext/agentics`](https://github.com/githubnext/agentics).

Each workflow is a markdown file in `.github/workflows/<name>.md` (the source
you edit) compiled to `.github/workflows/<name>.lock.yml` (what GitHub Actions
runs). Shared building blocks live in `.github/workflows/shared/`.

## The issue → PR → review loop

```
issue opened ──► Issue Triage (labels, duplicates, suggests next step)
     │
     ├─ /plan  ──► Plan: up to 5 agent-ready sub-issues
     ├─ /ask   ──► Ask: answers questions about the code
     └─ /scout (or add the `scout` label)
              ──► Scout (Claude Opus 5.5): research, implement, build/test, open PR
                       │
                       ▼
             PR ──► PR Code Quality Reviewer (/review; automatic on open/ready
                    and on every push to `scout`/`automation` PRs)
                       │
                       ├─ /pr-fix ──► PR Fix (Claude Opus 5.5): addresses review
                       │              comments + failing CI, pushes to the branch
                       │              ──► (push) ──► review again ──► …
                       ├─ /mergefest ──► merge the base branch in, resolve conflicts
                       └─ CI fails ──► CI Doctor comments a diagnosis on the PR
```

Typical session from the GitHub UI or mobile app:

1. Open an issue (or let Issue Triage label an existing one).
2. Comment `/scout` (optionally with hints, e.g. `/scout the bug is probably in Rel.fst`).
3. Scout opens a `[scout] …` PR that says `Fixes #N`.
4. The reviewer posts a review. Comment `/pr-fix` (optionally with
   instructions) to address it; repeat until happy, then merge.

Comment `/help` on any issue or PR to list all available commands.

## Workflows

| Workflow | Trigger | What it does | Model |
|---|---|---|---|
| [Scout](workflows/scout.md) | `/scout` on an issue, `scout` label, or manual dispatch | Researches the issue, implements a fix with a regression test, builds/tests F*, opens a PR, comments on the issue | Claude Opus 5.5 |
| [PR Code Quality Reviewer](workflows/pr-review.md) | PR opened / reopened / ready for review; pushes to `scout`/`automation` PRs; `/review` | Critical review incl. F*-specific soundness checks (`admit`, `assume`, rlimits, `.fsti` drift, `stage0`), inline comments + summary | Claude Opus 5.5 |
| [PR Fix](workflows/pr-fix.md) | `/pr-fix [instructions]` on a PR | Addresses review comments and failing CI, builds/tests, pushes to the PR branch | Claude Opus 5.5 |
| [CI Doctor](workflows/ci-doctor.md) | `CI` / `Nightly CI` run fails | Root-causes the failure from logs; comments on the PR, or opens/updates a `[CI failure]` issue | Copilot default |
| [Issue Triage](workflows/issue-triage.md) | issue opened/reopened, weekdays, manual | Adds a type label and `area/*` labels, finds duplicates, suggests `/scout` or `/plan` | Copilot default |
| [Plan](workflows/plan.md) | `/plan` on an issue | Breaks the issue into ≤5 small sub-issues ready for `/scout` | Copilot default |
| [Ask](workflows/ask.md) | `/ask <question>` on an issue or PR | Answers questions about the codebase with sources | Copilot default |
| [Mergefest](workflows/mergefest.md) | `/mergefest` on a PR | Merges the base branch into the PR branch and resolves conflicts | Copilot default |
| [Archie](workflows/archie.md) | `/archie` on an issue or PR | Mermaid diagrams of the issue/PR relationships or code structure | Copilot default |
| [Q](workflows/q.md) | `/q` | Investigates agentic workflow runs (logs, audits) and opens PRs that improve the workflows | Copilot default |
| [Craft](workflows/craft.md) | `/craft <description>` on an issue | Writes a new agentic workflow and opens a PR | Copilot default |
| [Sub-Issue Closer](workflows/sub-issue-closer.md) | daily, manual | Closes parent issues whose sub-issues are all done | Copilot default |
| [Weekly Repo Status](workflows/repo-status.md) | Mondays, manual | Status report issue: activity, CI health, agent PRs needing attention | Copilot default |

Generated support workflows (do not edit by hand):
`agentic_commands.yml` routes all slash commands (and `/help`) to the
workflows above; `agentics-maintenance.yml` closes expired agent outputs.

Workflows that build F* (Scout, PR Fix, Mergefest) import
[`shared/fstar-build-env.md`](workflows/shared/fstar-build-env.md), which runs
the same `.github/actions/setup-fstar-deps` action as `ci.yml` (opam switch +
Z3, cached) and checks out submodules.

`/scout` also allows users with read access to request issue-to-PR work.
Other slash commands that write code (`/pr-fix`, `/mergefest`, `/q`,
`/craft`, `/ask`) only run for users with write, maintain or admin access.

## One-time setup

1. **Copilot token** (required): create a fine-grained PAT for an account with a
   Copilot subscription, with the *Copilot Requests* permission, and add it as
   the `COPILOT_GITHUB_TOKEN` repository secret:

   ```bash
   gh aw secrets set COPILOT_GITHUB_TOKEN --value "<token>"
   ```

   (Or `gh secret set COPILOT_GITHUB_TOKEN`.) See
   <https://github.github.com/gh-aw/reference/auth/>.
   The Opus 5.5 model must be enabled for that account's Copilot.

2. **CI trigger token** (strongly recommended): pull requests and pushes made
   with the default `GITHUB_TOKEN` do not trigger other workflows, so without
   this neither `CI` nor the automatic re-review would run on agent PRs.
   Create a fine-grained PAT with *Contents: Read & write* on this repository
   and store it as `GH_AW_CI_TRIGGER_TOKEN`:

   ```bash
   gh aw secrets set GH_AW_CI_TRIGGER_TOKEN --value "<token>"
   ```

   gh-aw then pushes an extra empty commit with this token after creating or
   updating an agent PR. See <https://github.github.com/gh-aw/reference/triggering-ci/>.

3. **Actions settings**: under *Settings → Actions → General*, allow GitHub
   Actions to create and approve pull requests.

## Changing a workflow

Edit the `.md` file (frontmatter changes require recompiling; prompt-only
changes are picked up at runtime), then recompile with the same gh-aw version:

```bash
gh extension install github/gh-aw --pin v0.92.0   # once
gh aw compile --schedule-seed elefthei/FStar
```

and commit both the `.md` and the regenerated `.lock.yml` files. Without a
local checkout you can ask `/q` (to improve existing workflows) or `/craft`
(to create a new one) — they open PRs with the `.md` changes; then ask
`@copilot` on that PR to run `gh aw compile` and commit the lock files.
