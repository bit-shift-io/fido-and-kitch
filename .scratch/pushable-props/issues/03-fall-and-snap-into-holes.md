Status: pending

# Fall-and-snap: boxes drop into and fill holes

## What to build
The deterministic support/fall/snap model (ADR 0001) on the `Pushable` component. Support is decided by the solid map ground under the box's centre-x: while the centre is over solid ground the box rests wherever it is; once the centre passes over an unsupported tile, the box snaps its x to that tile's centre (within a small tolerance) and falls straight down. The box is un-pushable while airborne and pushable again once it lands. A box that lands filling a one-tile hole is solid, standable ground the player can walk across. A box whose fall path ends in water continues to the bottom map border and rests there (water is cosmetic + a crossed kill-zone sensor — no special-casing needed beyond letting it fall past).

## Files to create/modify
- src/components/pushable.lua (add support-under-centre-x check → rest vs fall; snap-target x math; suppress pushing while airborne)
- src/pushable/support.lua or similar small helper (new — pure functions: is there solid map ground under this x? snap-target centre-x for a given prop x and tile grid) patterned on src/player/ground_support.lua
- res/map/sandbox.(tmx|lua) (add a one-tile pit near the demo box so the fill-and-cross is demoable)
- tests/pushable_support_snap_test.lua (new, register in tests/run.lua)
- (reference) src/map.lua createStaticPhysicsBodies (map colliders have no `.entity`), map.tilewidth/tileheight, src/physics/bump/world.lua queries

## Test approach
Headless tests on the support/snap helper: centre over solid → supported (no fall), returns rest; centre over a gap → not supported, returns snap-target centre-x for that tile; snap tolerance behaves at the boundaries. Assert straight-down fall (no horizontal velocity introduced). Manual: push a box off a ledge into a one-tile pit → it snaps in, fills the gap, and the player walks across; push a box into water → it sinks to the bottom border and rests.

## Acceptance criteria
- [ ] A box resting with its centre over solid ground stays at its current x (no alignment).
- [ ] When the box's centre-x passes over an unsupported tile, it snaps to that tile's centre and falls straight down.
- [ ] The box is un-pushable while airborne, pushable again once landed.
- [ ] A box filling a one-tile hole is walkable across as solid ground.
- [ ] A box that falls into water rests on the bottom map border.
- [ ] Support and snap-target math covered by passing headless tests.

## Blocked by
Issue 02.
