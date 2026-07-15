Status: pending

# Enemy climbs overlapping ladders toward the target's Y

## What to build
When an enemy's target is meaningfully above or below it AND the enemy is currently overlapping a ladder, the enemy climbs the ladder (up or down, matching the player ladder mechanics: gravity off, fixed climb speed) toward the target's Y, dismounting when Y is as close as the ladder allows (or the ladder ends), then resumes X alignment. Purely opportunistic: the enemy never seeks a ladder out.

## Files to create/modify
- src/enemy/enemy_brain.lua (extend decision: when to mount, climb direction, when to dismount)
- src/enemy/ (climb handling in the enemy base/state machine; reuse ladder query pattern from src/player/player.lua queryLadder/queryLadderBelow)
- tests/enemy_brain_test.lua (extend)

## Test approach
Headless: given enemy overlapping/not-overlapping a ladder and a target above/below/level, assert mount/climb-direction/dismount decisions, including "target above but no ladder → keep aligning X". Manual: stand on a platform above a robot near a ladder — it climbs to you; without a ladder it paces underneath.

## Acceptance criteria
- [ ] Enemy overlapping a ladder with target above/below climbs toward the target's Y (gravity off while climbing).
- [ ] Enemy dismounts when Y is as close as possible or ladder ends, and resumes X alignment.
- [ ] Enemy with a vertical gap but no overlapping ladder just keeps aligning X.
- [ ] New headless tests pass via ./test.sh.

## Blocked by
01
