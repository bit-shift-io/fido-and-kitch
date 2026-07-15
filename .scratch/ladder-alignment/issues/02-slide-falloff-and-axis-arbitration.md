Status: pending

# On-ladder slide, edge fall-off, last-pressed arbitration

## What to build

While on a ladder, holding left/right shuffles the player sideways at a slow speed (~60, a new tunable on the player). The player keeps sliding as long as any part of the collider overlaps some ladder; the moment the collider fully clears every ladder they fall (transition to `FallState`). This adds a `sliding` mode to `LadderState`.

Because a vertical and a horizontal key can be held at once, movement is arbitrated **last-pressed-axis-wins**: whichever axis (vertical up/down vs horizontal left/right) was most recently *newly pressed* controls movement. When the active axis's keys are released, control falls back to the other axis if it is still held. This uses rising-edge detection per axis, following the existing `useDown` edge pattern in `WalkIdleState`.

The climb animation plays (advances frames) during any movement — sideways or vertical; when the player holds still on the ladder, the climb pose is static.

Re-aligning after a slide (pressing up/down to snap back to a centre) is NOT in this slice — here, pressing up/down while off-centre can simply climb in place / behave per the arbitration, with true re-centring added in issue 03. (If simplest, gate vertical climb on being centred so off-centre up/down is a no-op until 03 wires re-align.)

## Files to create/modify
- src/player/player_states.lua — add `sliding` mode to `LadderState`; wire fall-off → `FallState`; drive animation `playing` from "moving at all".
- src/player/player_movement.lua — pure seam for last-pressed axis resolution (given per-axis newly-pressed/held flags + previous active axis → active axis) and a fall-off decision (given overlap-any result → fall or stay).
- src/player/player.lua — per-axis edge state fields (like `useDown`) and reuse of the overlap-any-ladder query for the "still on a ladder?" test.
- Test file — extend the fast headless regression tests.

## Test approach
- Unit-test last-pressed axis resolution: pressing horizontal while vertical is held switches active axis to horizontal; releasing horizontal with vertical still held switches back to vertical; no new press keeps the current axis.
- Unit-test fall-off decision: overlaps at least one ladder → stay; overlaps none → fall.
- Decision-level check: holding left produces slow horizontal velocity while a ladder is overlapped, then a FallState transition once fully clear.

## Acceptance criteria
- [ ] Holding left/right on a ladder moves the player sideways at the slow slide speed.
- [ ] The player falls (FallState) exactly when the collider fully clears every ladder.
- [ ] Sliding across into a touching ladder does not cause a fall (overlap stays continuous).
- [ ] Holding a vertical then a horizontal key (or vice-versa) hands control to the most recently pressed axis; releasing it falls back to the still-held axis.
- [ ] The climb animation advances during any movement and is static when holding still.

## Blocked by
Issue 01.
