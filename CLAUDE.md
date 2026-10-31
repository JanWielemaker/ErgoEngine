# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

The reasoning engine of ErgoAI (formerly Flora-2): an F-logic / HiLog / defeasible-reasoning
language implemented in Prolog on top of **XSB** (it relies on XSB tabling, incl. incremental
and well-founded semantics). Installation and releases are documented upstream:
https://github.com/ErgoAI/.github/blob/main/profile/README.md

Top-level directories:

- `ErgoAI/` — the engine sources (this is what gets built and installed)
- `ErgoAI-testsuite/` — regression tests (golden-output based)
- `ErgoAI-performance/` — performance tests, same harness style
- `ErgoAI-website/` — static HTML for the project website

The sibling directory `../ergoAIstudio2/` (a separate repo, with its own CLAUDE.md) is a web IDE
that drives this engine. Its `ergoAIp/` subproject is a port of Ergo to SWI-Prolog. Neither is
part of this repo.

## Build

Building needs an XSB executable. `ergo_sanity_check.sh` looks for it in this order: the
explicit argument, `../XSB/bin/xsb` (the layout the installer uses: `XSB/` beside `ErgoAI/`),
then `xsb` on `$PATH`.

```sh
cd ErgoAI
./makeergo all /path/to/XSB/bin/xsb   # full build (core, libs, packages, demos, manuals)
./makeergo nodocs /path/to/xsb        # skip manuals and demos
./makeergo top /path/to/xsb           # just the top-level compiler modules (flr*.P)
./makeergo -S all ... / -P all ...    # subsumptive / non-incremental tabling variants
./makeergo clean | veryclean
```

Always build through `makeergo`, never `make` directly. `makeergo` writes `.ergo_paths` (which
sets `PROLOG`/`FLORADIR`, used by `runergo`), sets the default tabling mode in
`flrincludes/.ergo_default_tabling`, and touches the headers that force recompilation. The
Makefile does not compile files one by one. Its rules append `mc(Module,Options).` lines to a
`cmd...` file, and `CompileChangedFiles.sh` pipes that file into XSB in batches. Compiler
warnings are collected in `.__flora*.tmp` files and printed by the `showerrors` target.

Run the engine with `ErgoAI/runergo` (or `runflora`). `runergo --devel` keeps the XSB prompt
and banner and turns on profiling.

## Tests

Each test is a `.flr`/`.ergo` file that defines `%test`. The harness loads the file, runs
`%test.`, and compares the **sorted** output (in `temp`) against the golden file `<name>_old`,
using `diff -w`. If they differ, it leaves the actual output in `<name>_new`.

```sh
cd ErgoAI-testsuite
./testsuite.sh /path/to/ErgoAI                  # full suite; results in ergoaitest_summary.txt
./testsuite.sh -only "general_tests" /path/to/ErgoAI
./testsuite.sh -exclude "owltests json" /path/to/ErgoAI

# a single test: run from inside its directory
cd general_tests && ../test_one_file.sh /path/to/ErgoAI/runergo aggregate
```

- Logs go to `/tmp/ergoai_test_log.$USER`. A leftover `lock.test` file blocks new runs.
- The default list of test directories is in `testall.sh`.
- Each directory's `test_dir.sh` has an `exclude_list` of helper/aux files that other tests
  load. Add new helper files to that list.
- Tests write progress to `/dev/tty`, so they expect to run in a terminal.
- `ErgoAI-performance/` has its own `testsuite.sh`/`test_one_file.sh` with the same layout.

## Architecture

Ergo is a compiler from Ergo source to XSB Prolog. The entry point is `flora2.P`; the shell is
`flrshell.P`.

**Compilation pipeline**, applied to each statement (see
`ErgoAI/docs/implementation-notes/compilation-pipeline.txt`, and the driver in `flrutils.P`, e.g.
`flora_tokens` → `flora_parse` → `flora_compile`):

`flrlexer.P` (tokens) → `flrcomposer.P` (operator precedence, builds canonical terms) →
`flrparser.P` (canonical terms → parse trees) → `flrcompiler.P` (→ compiled intermediate terms)
→ `flrcoder.P` (writes XSB code that still contains gpp directives).

To extend the syntax, you usually change `flrparser.P` and `flrcompiler.P`. Syntax extension
hooks live in `extensions/` (e.g. `flrparser_*.P`). Operators are defined in `flroperator.P`;
the encoded predicate/term names that all of these modules share are in
`flrincludes/flora_terms.flh`.

**gpp and the trailer.** The generated code is run through XSB's gpp preprocessor and
specialised per Ergo *module* by macro substitution. Built-in axioms (inheritance, equality,
typing, …) are not generated per program. They are fixed code in the "trailer", included from:

- `closure/` (e.g. `flrcommon_inh.fli`, `flreqltrailer_inh.fli`)
- `includes/`, `genincludes/`, `headerinc/`, `flrincludes/`

**`.fli` → `.flh` generation.** Many `.flh` files are generated from `.fli` templates by
`flWrapAround/1` (`flrwraparound.P`), run from the per-directory Makefiles. Edit the `.fli`, not
the generated `.flh`, and re-run `makeergo` after changing any `.fli`/`.flh`.

**Runtime and libraries:**

- `syslib/` and `ergo_syslib/` — Prolog runtime support (aggregates, updates, fast loader,
  struct DB, alerts, ErgoText, …)
- `datatypes/` — built-in datatypes
- `debugger/` — tracer, table dump, Terminyzer
- `lib/` and `ergo_lib/` — system modules and libraries written in Ergo itself (`ergo2json`,
  `ergo2owl`, `ergo2java`, `ergo2http`, …)
- `pkgs/` and `ergo_pkgs/` — packages
- `AT/` — argumentation theories for defeasible reasoning (GCLP, ATCK, ATCO variants; tested
  in `ErgoAI-testsuite/defeasible/`)
- `cc/` — C interface
- `java/` — Java/InterProlog API
- `python/` — pyergo

Files prefixed `flr*`/`flora_*` date from Flora-2; `ergo_*` are later Ergo-specific additions.
The source uses both names.

**Compiled artifacts** are ignored by git: `.xwam` (XSB object), `.fls`/`.flt`/`.fdb`/`.fld`/`.flm`
(Ergo compilation output), and `.ergo_aux_files/` and `.flora_aux_files/` directories next to
sources. Stale aux files can mask changes. The test scripts delete them before running.

## Docs

- `ErgoAI/docs/ergo-manual.tex` — the main manual
- `ErgoAI/docs/extensions/*.tex` — manuals for individual features and packages
- `ErgoAI/docs/implementation-notes/` — internals (pipeline, encoding, omni-form, predicate
  dependency)
