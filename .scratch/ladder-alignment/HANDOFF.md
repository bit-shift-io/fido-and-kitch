# Ladder Alignment & Sliding — Handoff

## Summary

Rework how players interact with ladders. Today `LadderState` (`src/player/player_states.lua`) is kinematic with gravity off: you hold up/down to climb on a fixed vertical line at whatever x you mounted, with no sideways movement. This feature makes mounting *align* the player onto the ladder's centre before climbing, lets the player shuffle sideways on a ladder (falling off if they clear all ladders), and lets them cross between touching ladders.

The whole feature is a rework of the single `LadderState` — no new top-level FSM states. `LadderState` gains an internal **mode**: `aligning` (slide horizontally to a ladder centre), `climbing` (centred, up/down), `sliding` (left/right shuffle). Mode is chosen by **last-pressed-axis-wins** arbitration. State stays kinematic/gravity-off; the player only falls when the collider fully clears every ladder.

## Suggested implementation order

1. **Issue 01 — Mount alignment + climb.** Foundation: adds `aligning`/`climbing` modes and the nearest-centre + centred-test pure seams. Everything else builds on these. Initial mount slides at **walk speed**.
2. **Issue 02 — Slide, fall-off, arbitration.** Adds the `sliding` mode, slow slide speed, fall-off → FallState, and last-pressed-axis arbitration (per-axis rising-edge state, like `useDown`).
3. **Issue 03 — Re-align + adjacent crossing.** Wires `sliding` → `aligning` on a new up/down press at **slow** speed, giving the two-ladder crossing. Depends on the seams from 01 and the slide/arbitration from 02.

Each slice is demoable on its own (see each issue's Demo/acceptance criteria).

## Architecture notes / gotchas

- **Two horizontal speeds.** Initial ground mount = walk speed (`player.speed`, 100). All on-ladder horizontal (slide toward edge, re-align) = a **new slow tunable** (~60). The `aligning` mode must know which case it is (initial mount vs re-align). Don't reuse the unused `climbSpeed` field for the slow value — add a dedicated slide tunable so climb and slide stay independent.
- **Overlap-any = still on a ladder.** Reuse the existing overlap query (`queryLadder` bounds-overlap style in `player.lua:254`) as the "am I still on a ladder?" test. Fall only when it returns nothing. Note the acknowledged magic 4px bound insets in that query — keep behaviour, don't "fix" them as part of this work.
- **Exact-centre finish.** Snap x directly (`collider:setX`/`setPositionV` in `src/physics/love/collider.lua`) when within one slide-step of centre, rather than easing forever — avoids jitter/oscillation. Centre-x comes from `Rect:centre()` on the ladder (`src/utils/rect.lua`).
- **Edge tracking pattern.** Last-pressed arbitration mirrors the existing `use` edge detection in `WalkIdleState:update` (`player.lua` `useDown` bookkeeping). Directions are polled each frame via `Player:isDown` — there is no event system, so track per-axis previous-pressed state yourself.
- **Pure seams for tests.** Put decision logic (nearest-centre, centred test, axis resolution, fall-off) in `src/player/player_movement.lua` alongside `decideHorizontalMovement`, and cover with fast headless Lua regression tests (no graphical LÖVE launch). This is the established prior art.
- **Demo map.** `res/map/sandbox.tmx` already has two ladders (ids 60/61). For the issue-03 crossing demo you may want two *touching* ladders side by side — add a pair in the sandbox map if the existing ones aren't adjacent.

## No ADR

The mode model and last-pressed arbitration are localised to one FSM state and cheaply reversible — rationale is in DECISIONS.md, no ADR created. (ADR 0001 exists for the cross-cutting pushable snap model; this didn't meet the same bar.)

## Docs

- PRD.md — full requirements and acceptance criteria.
- DECISIONS.md — the grill Q&A and rationale (all 7 decisions + assumptions).
- Glossary (CONTEXT.md) — "Ladder mount alignment", "Ladder slide", "Ladder mode".
