# ADR 0002: Pushables are not grid-locked; support and fall decided by centre-x

**Status:** Accepted
**Date:** 2026-08-30

## Context
A pushable prop (the box, a boulder rolling into a gap, a prop shoved across
a hole) must decide, independent of grid tiles, whether it is supported and
where it falls. Authors push a box until it "drops in", and a boulder rolls
off a ledge; neither is snapped to a coarse tile grid after the fact. The
behaviour depends only on what is directly under the prop.

## Decision
Pushables are **not grid-locked**. Support, and the side a falling/settling
prop aligns to, is decided solely by what is under the prop's **centre-x**:

- A prop is supported if whatever is under its centre-x supports it; an edge
  barely overhanging a gap does not count, and nothing is decided by the
  other side of the prop.
- When nothing supports the centre, the prop falls **straight down** (it
  never arcs or shoves sideways), and on the way down it aligns to the hole
  / surface under its centre-x so it seats cleanly.
- The plate-seating forcing event fires on **push-RELEASE**, never mid-push,
  so the snap that seats a prop onto a plate can never fight the player's
  ongoing input.

## Alternatives Considered
- **Tile/normal-aligned movement** — lock props to a grid and let them only
  settle into exact tile cells. Rejected: props are shoved to arbitrary x
  positions along flat ground and must rest wherever they are left
  (`pushable_test.lua` "no grid alignment"), and a rolling boulder needs
  continuous motion, not cell-to-cell hops.
- **Whole-body support** — treat the prop as supported only when its entire
  footprint rests on something. Rejected at the centre-x rule: it makes
  legitimately overhanging-but-stable props misbehave and complicates the
  "drops in" case the designers actually use.

## Consequences
- A prop shoved along flat ground rests at whatever arbitrary x it was left
  at — no grid alignment (`pushable_test.lua` "no grid alignment").
- A prop whose centre-x clears a hole's edge aligns to the hole's tile
  centre and drops straight in (`pushable_test.lua` "ADR 0002's payoff").
- Players and designers get predictable, physically-intuitive behaviour
  where what you see under the prop is what decides its fate.
