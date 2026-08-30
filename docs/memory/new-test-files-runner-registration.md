---
name: new-test-files-runner-registration
description: A new unit/integration test file is never run by ./test-unit.sh or ./test-integration.sh unless it's added to a hardcoded list in run.lua.
metadata:
  type: convention
---

**Why:** `tests/unit/run.lua` and `tests/integration/run.lua` each hardcode a `defaultTestFiles` array. `./test-unit.sh`/`./test-integration.sh` with no arguments only load files in that list — a new test file sits there passing when run directly (`./test-unit.sh tests/unit/foo_test.lua`) while being silently absent from every full-suite run, including CI.
**How to apply:** Whenever a slice or task adds a new `tests/unit/*_test.lua` or `tests/integration/*_test.lua` file, add its path to the matching `defaultTestFiles` list in that tier's `run.lua` in the same change. Verify by running the bare `./test-unit.sh` / `./test-integration.sh` (no file argument) and confirming the new test's name appears in the output, not just a targeted run of the one file.

Separately, both runners currently abort the entire suite (not just one file) on an uncaught Lua error while loading any single test file — e.g. a missing `dkjson` dependency breaks every `level_generator_*_test.lua` file and stops the run before later files execute. When a bare `./test-unit.sh`/`./test-integration.sh` run ends early or shows a stack traceback instead of a pass/fail summary, that's this failure mode, not a signal that the whole suite is broken — cross-check by running the explicit non-broken file list before concluding anything regressed.
