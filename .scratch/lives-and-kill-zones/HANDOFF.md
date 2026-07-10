# Handoff — Water Kill Zones, Shared Lives & Game Over

## Summary

The sandbox level's water becomes lethal via designer-placed kill zones: rectangles on a new Tiled object layer (decoupled from the visual water tiles, each tagged `deathType="water"`). Players share a pool of lives (2, reset on every level load) shown as a row of red-square heart placeholders top-left. A killed player locks and flashes, then respawns at their last stably-grounded position and flashes again (movable immediately); level state and the other player are untouched. A death while the pool is at zero brings up a game over screen with Restart Level / Main Menu. Spawn flash also plays on initial map load.

Full requirements: `PRD.md`. Rationale for every decision: `DECISIONS.md`. No ADRs — nothing met the gate. New glossary terms (kill zone, death type, lives pool, last safe position) are in the root `CONTEXT.md`.

## Implementation order

1. **01, 02, 03 in any order (or parallel)** — three independent slices: kill-zone sensing (map data + entity + player query), lives pool + HUD (with the headless-tested lives seam), and safe-position tracking (headless-tested seam). Each is demoable alone.
2. **04 — death & respawn** — the integration slice; wires 01→02→03 together and builds the flash helper and `DeadState`. The feature is essentially playable after this.
3. **05 — spawn flash on load** — small; reuses 04's flash path.
4. **06 — game over screen** — replaces 04's stub hook; completes the feature.

## Architecture notes for the implementer

- **Follow the ladder, everywhere.** `src/entities/ladder.lua` is the template for the kill-zone entity (static sensor collider + `isLadder`-style flag); `Player:queryLadder()` in `src/player/player.lua` is the template for `queryKillZone()`; `LadderState:enter` in `src/player/player_states.lua` shows the kinematic/zero-gravity lock DeadState needs. Object types on objectgroups are auto-instantiated from `src/entities/<type>.lua` by `Map:loadEntity` — no map.lua changes needed for the new entity.
- **The game loads the Lua map export, not the tmx.** `InGameState:load` defaults to `res/map/sandbox.lua`. Any tmx edit must be re-exported from Tiled (the tmx has an export setting targeting `sandbox.lua`) or hand-mirrored into the Lua file.
- **Seams + headless tests are an established convention.** Pattern: `src/player/player_movement.lua` + `tests/player_movement_test.lua`, run with `./test.sh` (dependency-free, no LÖVE window; test files are `tests/<name>_test.lua`). The lives arithmetic and safe-position tracker must be pure seams with tests; don't reach for LÖVE mocks.
- **Globals are idiomatic here** (`world`, `map`, `game`, `camera`, classes preloaded in `main.lua`). Don't fight it — see the "Testability seam" glossary entry for the boundary.
- **HUD draws after `map:draw()`** in `InGameState:draw`, in raw screen coordinates — the map draws through its own canvas/scale transform (`Map:draw2`), and the HUD must stay outside it.
- **Lives semantics (confirmed twice):** pool starts at 2; deaths at 2 and 1 respawn; a death at 0 is game over — 3 deaths total. The HUD shows the raw counter, so an empty row while still playing is correct, intended behaviour.
- **Gotcha:** `InGameState:onPlayerDestroyed` (players leaving via the exit door) already exists and returns to the menu when all players leave — death/respawn must NOT go through `queueDestroy`/that path, or a mid-level death could dump everyone to the menu.
- Flash timings and the ~0.5 s stability threshold are feel-tuned, not contractual.

## Verification

`./test.sh` for the seams; `./run.sh` (optionally `love . map=sandbox.lua`-style arg — see `Game:init`) for everything visual. `conf.drawphysics` helps see the kill volumes.
