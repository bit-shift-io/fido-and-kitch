Status: done

# Walking skeleton: CLI → TMX → Tiled export → playable in game

## What to build
Running `tools/generate.sh --seed 42` produces a trivial but valid level — flat ground across the bottom, **one** spawn object, an open exit door (`actor_count` 0) — as a `.tmx` in `res/map/generated/`. (`src/states/ingame_state.lua` hardcodes `playerCount = 2` and spawns that many players *per spawn object found*; three of the four shipped maps use a single spawn object for both players, and the one exception with two spawn objects would spawn 4 players under this logic — a pre-existing game quirk, not a convention to copy. Generated levels use one spawn object.) The game loads `.tmx` directly (`src/map/init.lua`), so `love . map=generated/<name>.tmx` loads and plays it with no export step. `--count N` emits N maps, each independently reproducible (item seed derived from base seed). The chosen seed is always printed so unseeded runs can be reproduced.

## Files to create/modify
- tools/generate.sh
- tools/level_generator/main.lua
- tools/level_generator/rng.lua
- tools/level_generator/tmx_writer.lua

## Test approach
Headless tests (project `tests/` harness, `./test-unit.sh`): TMX writer golden-file test against a checked-in expected `.tmx` for a fixed seed; determinism test (same seed ⇒ identical string output, different seeds differ); RNG sequence reproducibility; batch item-seed derivation. Manual: generate, open in Tiled 1.12, run in LÖVE.

## Acceptance criteria
- [ ] `tools/generate.sh --seed 42` writes a `.tmx` to `res/map/generated/`
- [ ] The `.tmx` opens cleanly in Tiled with project tilesets resolving, and loads directly in the game (`love . map=generated/<name>.tmx`) with both players spawning
- [ ] Same seed + flags ⇒ byte-identical output; `--count 3` gives 3 distinct reproducible maps
- [ ] Golden-file and determinism tests pass via `./test-unit.sh`

## Blocked by
None — can start immediately.
