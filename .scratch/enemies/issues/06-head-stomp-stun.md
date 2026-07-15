Status: pending

# Head-stomp stuns enemies

## What to build
A player landing on an enemy from above stuns it for ~10s (default, tunable) and bounces the player upward. Works on both spider and robot. Detection is geometric (enemies are not solid to players): the player is falling (downward velocity), overlapping the enemy, and their feet are in the enemy's upper region. While stunned the enemy freezes in place (no chasing, shoving, wrapping, or climbing) with a visual indicator (e.g. flash or tint on the placeholder quad); it resumes its normal brain when the stun expires. Stomping does not start a harassment ban, and a stunned enemy can be re-stomped (timer restarts).

## Files to create/modify
- src/enemy/ enemy base (StunnedState + stomp detection; pure-logic stomp check function for tests)
- src/enemy/enemy_brain.lua (suspend decisions while stunned)
- tests/ (stomp geometry decision, stun timing)

## Test approach
Headless: stomp check — falling + overlap + from-above yields stomp; rising or side overlap does not; stun timer expires after duration. Manual: jump on a chasing robot — it freezes ~10s with a visible indicator while you bounce off; walking into it from the side does nothing; spider can be stomped before it reaches your partner.

## Acceptance criteria
- [ ] Falling onto an enemy from above stuns it ~10s and bounces the player upward.
- [ ] Side or rising contact never triggers a stomp; the spider's wrap doesn't fire from a stomping player during the same contact.
- [ ] Stunned enemies stop all behaviour, show a visual indicator, and resume normally on expiry.
- [ ] Stomp does not create a harassment ban.
- [ ] Headless tests pass via ./test.sh.

## Blocked by
01
