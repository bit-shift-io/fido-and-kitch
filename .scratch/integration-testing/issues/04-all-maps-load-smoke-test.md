Status: pending

# All real maps load without error

## What to build

A contributor gets automatic protection against a broken Tiled export or a bad entity `type` reference in any shipped level: an integration test that loads every exported map under `res/map/` through the same real `Game`/`InGameState`/`Map` stack used by other integration tests, and fails with the offending map's filename if any fails to load or errors during a handful of stepped frames.

## Files to create/modify

- tests/integration/all_maps_load_test.lua

## Test approach

Enumerate `res/map/*.lua` (the exported maps, matching what `Map:new`/STI actually load — not the `.tmx` sources), and for each: start a fresh `Game`, jump to `InGameState:startGame({map=...})`, step a small fixed number of frames via the frame stepper, and assert no error was raised. On failure, the assertion message must name the specific map file that failed, so a broken level is immediately identifiable from the test runner's output.

## Acceptance criteria

- [ ] Every file under `res/map/*.lua` is loaded and stepped a few frames without error.
- [ ] A failing map's filename appears in the test failure output.
- [ ] Adding a new map under `res/map/` requires no test-file changes (the list is discovered, not hardcoded).

## Blocked by

01-harness-foundation
