Status: pending

# Pushable component: continuous slide + push gating

## What to build
A reusable `Pushable` component (slide mode) added to `push_box`. A grounded player who walks into a box and holds the direction slides the box at the player's walk speed; the box stops the instant the player stops moving, releases the direction, or turns away. The player must be grounded — a mid-air collision just blocks. The box is blocked by walls and other pushables (pushing a box into another prop moves neither). Gating: the box is un-pushable while another pushable rests on top of it, and un-pushable while a player stands on top of it unless the box's `allowPushWhenStoodOn` property is set.

After this slice, a box can be freely repositioned along flat ground, resting at arbitrary x (no forced alignment yet — holes are the next slice).

## Files to create/modify
- src/components/pushable.lua (new — slide behaviour + a pure "can push now?" decision helper: pusher grounded + holding a direction into the prop, nothing pushable on top, no player on top unless opted in)
- src/entities/push_box.lua (add the Pushable component; read `allowPushWhenStoodOn` from `object.properties`)
- src/player/player.lua (add a horizontal contact/probe so the player-driven push is detected; mirror existing query patterns e.g. queryLadder / queryOnGround) — or drive it from the component using existing collision info; choose the lighter-touch option
- res/templates/push_box.tx (add `allowPushWhenStoodOn` custom property, default false)
- tests/pushable_push_gating_test.lua (new, register in tests/run.lua)
- (reference) src/player/ground_support.lua, src/physics/bump/world.lua queries, src/player/player_movement.lua for walk speed

## Test approach
Headless decision tests on the "can push now?" helper and the resulting slide velocity: pusher grounded + holding into box → box moves at walk speed in that direction; not grounded / not holding / turned away → no move; pushable on top → no move; player on top → no move unless opted in; blocked by a prop/wall on the far side → no move. Follow tests/player_movement_test.lua / ground_support_test.lua style. Manual: push a box left/right along flat ground; confirm stop-on-release and blocking.

## Acceptance criteria
- [ ] A grounded player holding a direction into a box slides it at walk speed.
- [ ] The box stops immediately when the player stops, releases, or turns away.
- [ ] A mid-air player cannot push (only blocks).
- [ ] A box with a pushable on top cannot be pushed.
- [ ] A box with a player on top cannot be pushed unless `allowPushWhenStoodOn` is set.
- [ ] Pushing a box into a wall or another pushable moves neither.
- [ ] Gating and slide-decision logic covered by passing headless tests.

## Blocked by
Issue 01.
