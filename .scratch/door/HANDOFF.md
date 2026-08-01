# Door Entity — Handoff

## Summary

A new `door` entity: a player- and pushable-blocking obstacle that starts
closed and is opened/closed by an external switch or pressure switch, using
the codebase's existing `target` + `:switch(switch, user)` convention
(currently only implemented by `ladder`). It reads the caller's `state`
directly ('on' → open, 'off' → close) rather than toggling independently, so
it works unmodified with both a lever switch and a pressure switch (momentary
or latching), and supports several switches each independently targeting the
same door.

Visually it follows the drawbridge's two established patterns: a reversible
timeline animation for opening/closing (with mid-transition interrupts
reversing in place), and a 1-tile editor footprint that draws as a 3×3 sprite
box in-game. Its blocking collider deliberately extends taller than its own
tile, following `createStaticPhysicsBodyBoundary`'s pattern — the codebase
has a documented gotcha that a collider flush with the walking surface's top
edge doesn't reliably block horizontal movement under bump's AABB
resolution, and a locked door is the example AGENTS.md calls out directly.

As a demonstration, the sandbox map's existing switch (object id 44), whose
`target` currently points at the exit door (which has no `:switch()`
handler and so is a no-op today), gets re-targeted to a newly placed door
near the switch.

## Implementation Order

1. **`01-door-entity.md`** — the entity itself: state machine, animation,
   collision, sound, and the Tiled template/editor art. Fully demoable and
   testable in isolation (headless unit + entity tests, manual placement in
   any map).
2. **`02-sandbox-wiring.md`** — depends on 01. Places a door in
   `sandbox.tmx` and re-points the existing switch's `target` at it.

## Links

- `PRD.md` — full requirements, user stories, acceptance criteria.
- `DECISIONS.md` — grill Q&A and rationale, including the AABB-collider
  gotcha cross-check (Q3) and why no ADR was needed.
- `CONTEXT.md` — new "Door" glossary entry.

## Implementer Notes

- No ADR needed for this feature — every design choice follows an existing,
  established pattern rather than introducing a new one (see DECISIONS.md's
  "Trade-offs Considered").
- `Door.isDoorSolid(state)` is the inverse of `Drawbridge._internal
  .isDeckSolid` — solid whenever state is *not* `'open'`, vs. the
  drawbridge's solid whenever state is *not* `'closed'`. Easy to flip by
  accident if copy-pasting from drawbridge — double check the sense of this
  predicate against DECISIONS.md Q6.
- The door has no `update()`-driven occupancy polling at all (unlike
  drawbridge/pressure_switch) — it's purely event-driven from `:switch()`.
  Don't reach for `world:queryOverlap` here; there's nothing to poll.
- The tileset already has door art wired up at `res/tilesets/props.tsx` tile
  id 5 (gid 6) — currently only used by `exit_door`'s template. Reuse it
  rather than adding a new tileset entry; no new art asset is in scope.
- No sound assets exist yet for open/close — reference wav paths that don't
  exist, same as `pressure_switch` already does; `Sound:play` degrades
  gracefully.
- Known test/reference files to mirror: `src/entities/drawbridge.lua` +
  `tests/unit/drawbridge_test.lua` (animation, sprite bleed, `_internal`
  seam), `src/entities/pressure_switch.lua` (target/`:switch()` wiring,
  latching vs. momentary), `src/entities/ladder.lua` (the only existing
  `:switch()` implementer).
