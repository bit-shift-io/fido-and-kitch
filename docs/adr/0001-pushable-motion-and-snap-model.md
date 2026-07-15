# ADR 0001: Deterministic pushable motion & snap model

**Status:** Accepted
**Date:** 2026-07-15

## Context

Pushable props (boxes, boulders) need to fall into gaps and reliably *fill* one-tile holes so the player can walk across — that's the whole puzzle payoff. The game runs on a custom platformer physics layer over the `bump` AABB library, where a dynamic body naturally teeters and falls off a ledge once its centre of mass passes the edge, landing wherever momentum leaves it.

Left to raw physics, a box shoved toward a one-tile pit would fall off-centre and rarely sit flush in the gap, making "fill the hole and cross" unreliable — and pressure-plate puzzles need the box to sit cleanly *on* the plate, not half-off it.

## Decision

Pushables use a **deterministic support-and-snap model** layered on top of the physics, not free-body teetering:

- **Support is decided by the solid map ground under the prop's centre-x.** While the centre is over solid ground, the prop rests at whatever x it was left at — no forced grid alignment during normal sliding.
- **Falling is a snap event.** Once the prop's centre-x passes over an unsupported tile, it snaps its x to that tile's centre (within a small tolerance) and falls straight down (zero horizontal velocity via the existing gravity path). It is un-pushable while airborne and pushable again on landing. A prop that lands filling a hole is solid ground.
- **Pressure-plate seating is also a snap event**, but fired on push-release rather than during motion: when the player stops pushing and the prop's centre-x is within tolerance of a plate tile centre, the prop snaps to that centre. Firing on release (not mid-push) keeps the snap from fighting the player's input.

Alignment therefore only ever happens on these two forcing events; everywhere else props move and rest continuously.

## Alternatives Considered

- **Pure physics (fall when >50% off a ledge, no snap).** Rejected: props land off-centre, so one-tile holes don't fill reliably and plates aren't cleanly triggered.
- **Full grid-locked (Sokoban) movement.** Rejected: too rigid for the desired continuous slide feel; the user explicitly wants free positioning with alignment only as an event.

## Consequences

- Puzzle levels can depend on tile-perfect hole-filling and clean plate seating.
- The model is a deliberate departure from the physics engine's default fall behaviour — a future reader will see props ignoring normal ledge teetering, which this ADR explains.
- It is comparatively hard to reverse once levels are authored around deterministic snapping: switching to physics-driven falling later would require re-tuning or rebuilding those puzzles.
- Adds a small amount of per-prop decision logic (support-under-centre-x, snap-target math) that must stay in sync with tile size; this logic is extracted into a testable helper.
