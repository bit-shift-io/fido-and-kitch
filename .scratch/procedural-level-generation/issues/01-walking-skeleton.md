Status: pending

# Walking skeleton: CLI → TMX → Tiled export → playable in game

## What to build
Running `tools/generate.sh --seed 42` produces a trivial but valid level — flat ground across the bottom, two spawn points, an open exit door (`actor_count` 0) — as a `.tmx` in `res/map/generated/`, auto-exports it to `.lua` via the Tiled CLI, and `love . map=generated/<name>.lua` loads and plays it. `--count N` emits N maps, each independently reproducible (item seed derived from base seed). If Tiled isn't found, the tool emits `.tmx` only and prints a clear warning. The chosen seed is always printed so unseeded runs can be reproduced.

## Files to create/modify
- tools/generate.sh
- tools/level_generator/main.lua
- tools/level_generator/rng.lua
- tools/level_generator/tmx_writer.lua
- tools/level_generator/export.lua

## Test approach
Headless tests (project `tests/` harness, `./test.sh`): TMX writer golden-file test against a checked-in expected `.tmx` for a fixed seed; determinism test (same seed ⇒ identical string output, different seeds differ); RNG sequence reproducibility; batch item-seed derivation. Manual: generate, open in Tiled 1.12, run in LÖVE.

## Acceptance criteria
- [ ] `tools/generate.sh --seed 42` writes `.tmx` + `.lua` to `res/map/generated/`
- [ ] The `.tmx` opens cleanly in Tiled with project tilesets resolving; the `.lua` loads in the game with both players spawning
- [ ] Same seed + flags ⇒ byte-identical output; `--count 3` gives 3 distinct reproducible maps
- [ ] Missing Tiled CLI degrades gracefully with a warning
- [ ] Golden-file and determinism tests pass via `./test.sh`

## Blocked by
None — can start immediately.
