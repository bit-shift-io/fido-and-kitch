Status: pending

# Mount alignment + climb

## What to build

Pressing up (or down) while overlapping a ladder off-centre makes the player slide horizontally onto that ladder's centre-x, and only then start climbing vertically. The slide is at walk speed (`player.speed`, 100); once centred, vertical movement uses the existing climb speed (100). Alignment finishes exactly on centre-x — no jitter, no oscillation.

This reworks `LadderState` to have two internal modes: `aligning` (moving horizontally toward the target centre, no vertical motion) and `climbing` (centred, up/down move vertically as today). The state stays kinematic with gravity off throughout. When more than one ladder is overlapped, the target is the ladder whose centre-x is nearest the player's current centre-x.

No sideways movement *on* the ladder in this slice — left/right do nothing while climbing yet.

## Files to create/modify
- src/player/player_states.lua — rework `LadderState` (enter/update) to add `aligning`/`climbing` modes and the mount slide.
- src/player/player_movement.lua — add pure decision seams: nearest-ladder-centre selection (given player centre-x + list of ladder rects/centres) and a "centred within one step" test.
- src/player/player.lua — expose a helper to gather all currently-overlapping ladders (generalise/reuse `queryLadder`), if not already available; keep the existing `queryLadder`/`queryLadderBelow` for the mount trigger.
- Test file (fast headless Lua regression, co-located per existing convention) for the new pure functions.

## Test approach
- Unit-test the pure seams in `player_movement.lua`:
  - nearest-ladder-centre: given a player centre-x and several ladder centres, returns the closest; ties resolve deterministically.
  - centred test: returns true when |playerX − centreX| ≤ one slide-step for the frame, false otherwise.
- Verify (manually or via a decision-level test) that: entering the ladder off-centre yields horizontal velocity toward the centre at walk speed and zero vertical velocity; once centred, x is snapped exactly and vertical velocity is applied for up/down.

## Acceptance criteria
- [ ] Pressing up while overlapping a ladder off-centre slides the player toward that ladder's centre at walk speed, with no vertical motion during the slide.
- [ ] Pressing down at the top of a ladder off-centre does the same, then descends.
- [ ] On reaching centre, x is exactly the ladder centre-x (no visible jitter) and climbing begins.
- [ ] Once centred, up/down climb vertically at the existing climb speed.
- [ ] When two ladders are overlapped, alignment targets the nearest centre-x.
- [ ] Gravity stays off for the whole state; leaving the top/bottom of the ladder behaves as today.

## Blocked by
None — can start immediately.
