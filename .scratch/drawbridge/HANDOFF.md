# Drawbridge — Handoff

## Summary

The **drawbridge** is a one-way tile: a single-tile crossing placed in Tiled over a real gap. It starts closed and blocks passage like a wall (nobody falls by bumping it). When an *eligible* entity — a player by default — approaches from the designer-set *correct side*, the bridge lowers (open animation) into solid, walkable ground. Once open it's solid to everyone from either direction, so a second player or a chasing enemy can follow across. It stays open while anything overlaps its tile and raises (open animation played in reverse) once the last entity leaves, reversing in place if re-triggered mid-close. It resets to closed on level restart.

A supporting capability lands first: a **reversible Timeline/Sprite playback API** so one authored open animation serves both the open (forward) and close (reverse) transitions. The `Timeline` component already carries the primitives (`isReverse`, `reverse()`, `resetReverse()`, `speed`, signed `progress`, dual-end handling in `fireEvents`); slice 01 hardens them into a tested public API.

## Suggested implementation order

1. **01 — Reversible Timeline API** and **02 — Closed drawbridge that blocks** can start in parallel; neither depends on the other. Do 01 first if serialising, since 03 needs it.
2. **03 — Open on correct-side approach** (needs 01 + 02): trigger sensor, open animation, deck-solid flip, crossing.
3. **04 — Occupancy close + reverse-in-place interrupt** (needs 03): the raise animation and the mid-close reversal.
4. **05 — Eligibility + enemy-follow + reset + integration test** (needs 04): layer the Tiled eligibility property, enemy opt-in, spawn-state reset, and the end-to-end integration test on top of the complete lifecycle.

## Collision model (read before coding the entity)

The bridge uses a **two-collider swap**, not a directional collision filter:

- **Closed:** a solid **closed barrier** collider blocks horizontal entry (bump = wall, no fall); **no walkable deck**. The gap below is real, authored by the designer in terrain.
- **Open:** a solid **deck** collider (walkable ground spanning the gap); **no closed barrier**.
- A **trigger sensor** on the correct side (mirrored by `facing`) is always present and, on overlap by an eligible entity, starts the open — positioned so the deck lowers *before* the entity reaches the gap.

Solidity is tied to the transition and must stay coherent through a mid-close reversal; occupancy keeps the bridge open while anyone overlaps, which is what guarantees an occupant is never dropped.

## Implementer notes / gotchas

- Reuse the sensor/overlap collision path the way `ladder.lua`, `switch.lua`, and `jump_pad.lua` do (static sensor colliders, `object.properties.*` config). Mirror the sprite with the existing `Sprite:setFacing`.
- Occupancy and eligibility both come down to a world query over the bridge tile plus a small decision helper — extract these as pure functions and test them headless, mirroring `src/player/ground_support.lua` + `tests/ground_support_test.lua`.
- The designer authors the gap and any kill zone under the bridge separately; the entity does not create terrain or hazards.
- Build the fixture map (ground + 1-tile gap + drawbridge + spawns both sides, plus an enemy for slice 05) in slice 02 and reuse it through 03–05.
- Validate logic with `./test.sh`; validate feel with `love . drawphysics map=<fixture>.lua` (F1 toggles collision boxes per recent editor work).

## Links

- PRD: `.scratch/drawbridge/PRD.md`
- Decisions & rationale: `.scratch/drawbridge/DECISIONS.md`
- Issues: `.scratch/drawbridge/issues/01…05`
- No ADR — the collision model is localised to one entity and captured in DECISIONS.md (Q3/Q4); it didn't meet the ADR gate.
- Prior art: `.scratch/pushable-props/` (Tiled-placed, component-composed prop with reset-on-restart and headless decision-helper tests).
