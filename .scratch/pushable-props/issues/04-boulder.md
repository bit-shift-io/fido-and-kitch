Status: pending

# Boulder: momentum roll variant

## What to build
A `boulder` prop that reuses the `Pushable` component in roll mode. It starts moving the same way a box does (a grounded player walks into it and holds the direction), but once moving it keeps rolling on its own at the player's walk speed after contact ends. It stops when it hits a wall, another pushable, or a player, or when it falls into a gap (snapping and falling straight down like a box). It never harms or shoves the player — on contact it simply stops. Once stopped, it can be pushed again if there is room, including back the other way. Rendered as a 32×32 placeholder quad (grey).

## Files to create/modify
- src/entities/boulder.lua (new — `Class{__includes = Entity}`, dynamic Collider 32×32, Pushable in roll mode, grey placeholder quad)
- src/components/pushable.lua (add roll mode: after an initial push, keep applying roll velocity until a stop condition; reuse the fall/snap from issue 03)
- res/templates/boulder.tx (new — `type="boulder"`)
- res/map/sandbox.(tmx|lua) (place a boulder + a wall/gap so rolling and stopping are demoable)
- tests/pushable_roll_test.lua (new, register in tests/run.lua)

## Test approach
Headless tests on roll continuation and stop conditions: after an initial push the boulder keeps a roll velocity with no ongoing contact; it zeroes on hitting a wall / pushable / player; it transitions to fall+snap when its centre passes a gap. Assert it does not damage or move a player it contacts (contact → stop only). Manual: shove a boulder across flat ground and watch it roll into a wall (stops) and into a pit (falls and snaps).

## Acceptance criteria
- [ ] A grounded player walking into a boulder starts it rolling.
- [ ] It keeps rolling at walk speed after the player stops touching it.
- [ ] It stops on hitting a wall, another pushable, or a player (harmlessly — no damage, no shove).
- [ ] It falls and snaps into a gap like a box.
- [ ] It can be pushed again once stopped, if there's room, in either direction.
- [ ] Roll/stop logic covered by passing headless tests.

## Blocked by
Issue 03 (reuses fall/snap and the Pushable component).
