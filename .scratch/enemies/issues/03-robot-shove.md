Status: pending

# Robot shoves overlapping players

## What to build
While the robot overlaps a player, it applies a steady, gentle sideways shove (pushing the player away in the robot's facing/movement direction) that visibly displaces them but is always escapable by walking or jumping away. Hazard-blind: the shove doesn't care what's nearby; it must be weak enough that it can only cause a death through the player's own positioning. Wrapped players (issue 05) must be immune — build the immunity check against a `player.wrapped`-style flag now, even though nothing sets it yet.

GOTCHA: the player's WalkIdleState and PlayerMovement rewrite horizontal velocity from input every frame, so a velocity impulse will be overwritten — apply the shove as a per-frame position offset (or a post-movement velocity add) instead. See HANDOFF.md.

## Files to create/modify
- src/entities/robot.lua (overlap detection + shove application)
- src/enemy/enemy_brain.lua or a small pure shove-decision function (direction/strength given overlap geometry)
- tests/ (new or extended test file for shove decision)

## Test approach
Headless: shove direction/magnitude decision from relative positions; zero shove when target is wrapped. Manual: let the robot reach you — you get nudged but can always walk out of it; get shoved near a ledge and confirm you can recover with normal movement; confirm a shove never outruns player walk speed.

## Acceptance criteria
- [ ] Overlapping robot displaces the player sideways smoothly, every frame of overlap.
- [ ] Shove speed is comfortably below player walk speed (tunable, Tiled-overridable).
- [ ] Players flagged as wrapped are not displaced.
- [ ] Shove works despite the player's per-frame velocity reset (verified in manual play).
- [ ] Headless tests pass via ./test.sh.

## Blocked by
01
