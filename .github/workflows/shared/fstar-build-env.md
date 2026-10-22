---
# Shared F* build environment for agentic workflows that need to build or
# test F* (Scout, PR Fix, CI Doctor, ...).
#
# Reuses the same composite action as ci.yml (.github/actions/setup-fstar-deps)
# so the agent gets the opam switch (OCaml + F* deps) and the Z3 versions used
# by F*, restored from the Actions cache when possible.
#
# Usage:
#   imports:
#     - shared/fstar-build-env.md
checkout:
  submodules: true
network:
  allowed:
    - defaults
    - github
    - ocaml
steps:
  - name: Set up F* dependencies (opam switch + Z3)
    uses: ./.github/actions/setup-fstar-deps
---

## F* build environment

The F* build dependencies (OCaml/opam switch with F*'s opam deps, and Z3) have
already been installed by a setup step, using the same action as the `CI`
workflow (`.github/actions/setup-fstar-deps`). The opam environment variables
are exported, and Z3 binaries are on `PATH` (in `~/bin`).

Useful commands (see `make help` and `CONTRIBUTING.md`):

- `make -skj$(nproc) 2` — build the stage 2 compiler and libraries (what most changes need).
- `make -skj$(nproc) build` — full build (stage 3, including Pulse).
- `make -skj$(nproc) test` — run the regression tests and examples (slow).
- `make -skj$(nproc) unit-tests` — the smaller unit test suite.
- `make check-fsti-impls` — check every `.fsti` in `ulib`/`pulse/lib` has an implementation.
- `make -skj$(nproc) ci` — exactly what the `CI` workflow runs (very slow; prefer targeted targets).
- To check a single file with a built compiler: `out/bin/fstar.exe path/to/File.fst` (add `--include` paths as needed).

Build guidance:

- Full builds and test suites are slow. Prefer the narrowest target that
  validates your change, and run long commands with a generous timeout.
- The F* compiler is written in F* and extracted to OCaml; the extracted
  snapshot lives under `stage0/`. Do **not** refresh the snapshot
  (`make save` / `make bump-stage0`) unless explicitly asked to.
- Add regression tests (positive and, where sensible, negative ones using
  failure attributes like `[@@expect_failure]`) for bug fixes, as requested
  by `CONTRIBUTING.md`.
- If a change is non-backwards-compatible, update `CHANGES.md`.
