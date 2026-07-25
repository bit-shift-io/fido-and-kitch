# Drawbridge — Handoff

## Summary

The **drawbridge** is a one-way tile: a single-tile crossing placed in Tiled over a real gap. It starts closed, and the gap is fully exposed — approaching from the wrong side means falling in, like any other pit (revised post-playtesting from an earlier "blocks like a wall" design; see DECISIONS.md Q4). When an *eligible* entity — a player by default — approaches from the designer-set *correct side*, the bridge lowers (open animation) into solid, walkable ground. Once open it's solid to everyone from either direction, so a second player or a chasing enemy can follow across. It stays open while anything overlaps its tile and raises (open animation played in reverse) once the last entity leaves, reversing in place if re-triggered mid-close. It resets to closed on level restart.

A supporting capability lands first: a **reversible Timeline/Sprite playback API** so one authored open animation serves both the open (forward) and close (reverse) transitions. The `Timeline` component already carries the primitives (`isReverse`, `reverse()`, `resetReverse()`, `speed`, signed `progress`, dual-end handling in `fireEvents`); slice 01 hardens them into a tested public API.

## Suggested implementation order

1. **01 — Reversible Timeline API** and **02 — Closed drawbridge that blocks** can start in parallel; neither depends on the other. Do 01 first if serialising, since 03 needs it.
2. **03 — Open on correct-side approach** (needs 01 + 02): trigger sensor, open animation, deck-solid flip, crossing.
3. **04 — Occupancy close + reverse-in-place interrupt** (needs 03): the raise animation and the mid-close reversal.
4. **05 — Eligibility + enemy-follow + reset + integration test** (needs 04): layer the Tiled eligibility property, enemy opt-in, spawn-state reset, and the end-to-end integration test on top of the complete lifecycle.

## Collision model (read before coding the entity)

**No barrier.** (Original design had one — see DECISIONS.md Q4 for why it was removed after playtesting.) Just one collider that toggles solidity, plus an always-present trigger:

- **Closed:** the deck collider is a sensor (non-solid) — the gap is fully exposed, a real hazard from either side.
- **Opening/open/closing:** the deck collider is solid (walkable ground spanning the gap), coherently across all three states so an occupant is never dropped and a mid-close reversal never has to flip solidity.
- A **trigger sensor** on the correct side (mirrored by `facing`) is always present and, on overlap by an eligible entity, starts the open — positioned so the deck lowers *before* the entity reaches the gap.

Occupancy keeps the bridge open while anyone overlaps, which is what guarantees an occupant is never dropped.

## Implementer notes / gotchas

- Reuse the sensor/overlap collision path the way `ladder.lua`, `switch.lua`, and `jump_pad.lua` do (static sensor colliders, `object.properties.*` config). Mirror the sprite with the existing `Sprite:setFacing`.
- Occupancy and eligibility both come down to a world query over the bridge tile plus a small decision helper — extract these as pure functions and test them headless, mirroring `src/player/ground_support.lua` + `tests/ground_support_test.lua`.
- The designer authors the gap and any kill zone under the bridge separately; the entity does not create terrain or hazards.
- Build the fixture map (ground + 1-tile gap + drawbridge + spawns both sides, plus an enemy for slice 05) in slice 02 and reuse it through 03–05.
- Validate logic with `./test.sh`; validate feel with `love . drawphysics map=<fixture>.lua`. Note: this repo's AGENTS.md claims F12 is a screenshot key — it isn't actually wired up in `src/main.lua`; there's no in-game screenshot binding currently.
- **Collider `enter`/`exit`/`use` callbacks that need their argument must be wired with `utils.func(fn, self)`, not `utils.forwardFunc(fn, self)`.** `forwardFunc` drops the single argument these callbacks receive (it lands as `forwardFunc`'s discarded `oldSelf`, not in `...`). `ExitDoor:contact` and `Ladder`'s commented-out `enter`/`exit` get away with it only because their bodies never read the argument. `jump_pad.lua`'s `Usable{use=utils.func(...)}` is the correct precedent to copy.
- **The installed `love` binary here is 11.5, but `conf.lua` targets `t.version = "12.0"`**, so LÖVE sometimes shows a native "Compatibility Warning" alert on launch, on top of the game window. If you automate manual verification (e.g. via `osascript`/AppleScript), dismiss it with a real synthesized mouse click (`cliclick`) — dismissing via the Accessibility API (`System Events click button "OK"`) can leave the game window unable to receive further synthesized keyboard input, which looks exactly like the game being frozen and is a significant time sink to rule out.
- No Tiled GUI was available in this environment; `res/map/drawbridge_fixture.lua` was hand-written directly in STI's exported-Lua table shape rather than authored in Tiled and exported. It loads and plays correctly, but there's no `.tmx` source for it — re-author properly in Tiled if you have it available.

## Status (as of this session)

All five slices are done. The feature was paused mid-03 to build a proper headed/headless test harness (`.scratch/integration-testing/` and `.scratch/headed-e2e-tests/`, both since folded into `tests/unit|integration|e2e/` and their own `test-*.sh` scripts — see `tests/README.md`) rather than continue debugging through manual screenshot/AppleScript verification; once that harness existed, the remaining work (03's real bug, 04, 05) went quickly with fast, deterministic repros.

- **01 (reversible Timeline API): done.**
- **02 (closed drawbridge blocks): done.**
- **03 (open on correct-side approach): done.** The "player stuck mid-crossing" bug was root-caused with the new harness: `Player:queryOnGround()`/`GroundSupport` don't recognise an entity-owned collider as ground without an explicit `collider.walkable = true` opt-in (the deck now sets it), and a solid rect flush with the ground's own top edge resolves as a walkable step, not a wall, under this project's AABB collision (the barrier is now taller than the tile). Both are now general `tests/README.md` gotchas, not drawbridge-specific.
- **04 (occupancy close + reverse-in-place): done.** One additional real bug: occupancy closing the bridge the instant `open` was reached (same frame as the animation-finish event, before the triggering entity had physically arrived — by design the trigger leads the gap) needed a `hasBeenOccupied` edge-triggered guard, not a plain "currently unoccupied" check.
- **05 (eligibility, enemy-follow, reset): done.** Two more real bugs surfaced building its tests, both now documented in `tests/README.md`: `World:queryBounds`'s movement-based `check()` doesn't reliably find dynamic bodies (added `World:queryOverlap`, a real AABB query, for occupancy); and `collider.groupIndex` defaulting to `nil` on both sides silently disables collision between any two ungrouped colliders (a bare test collider needs an explicit one).
- **Post-ship design revision: the barrier was removed.** After playtesting the shipped feature live, "blocks like a wall from the wrong side" was reversed — see DECISIONS.md Q4's revision, `issues/02`'s and `issues/03`'s superseded notes. Removing the barrier surfaced two more real bugs (`Player:queryOnGround()`/`GroundSupport` not checking a walkable collider's *current* sensor state; a fixture map's declared `height` shorter than its own kill zone, so the world's own boundary wall stopped the fall before it reached the kill zone) — both fixed, both documented in `tests/README.md`.

Full test suite: `./test-unit.sh && ./test-integration.sh && ./test-e2e.sh` (or `./test-all.sh`). All green except one pre-existing, unrelated flaky camera test (`tests/unit/camera_test.lua`, confirmed flaky on `main` before this feature too).

## Links

- PRD: `.scratch/drawbridge/PRD.md`
- Decisions & rationale: `.scratch/drawbridge/DECISIONS.md`
- Issues: `.scratch/drawbridge/issues/01…05`
- No ADR — the collision model is localised to one entity and captured in DECISIONS.md (Q3/Q4); it didn't meet the ADR gate.
- Prior art: `.scratch/pushable-props/` (Tiled-placed, component-composed prop with reset-on-restart and headless decision-helper tests).
