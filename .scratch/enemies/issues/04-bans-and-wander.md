Status: pending

# Harassment bans and wander state

## What to build
Per-enemy, per-player harassment bans, plus a wander fallback:

- Generic ban API on the enemy brain: `ban(player, duration)`; banned players are excluded from target selection until their timer (default 30s) expires.
- Robot rule: after ~10s (default, tunable) of cumulative pursuit of the same target (clock runs while that player is the chosen target), the robot bans that player for 30s and re-targets.
- Wander: when no valid target exists (all players banned, wrapped, or dead), the enemy ambles back and forth in a small range around its current position, returning to chase the moment a target becomes valid.

The spider (issue 05) will call the same `ban()` on wrap.

## Files to create/modify
- src/enemy/enemy_brain.lua (ban table + timers, chase-duration tracking, wander decision)
- src/enemy/ enemy base (wander movement/state)
- src/entities/robot.lua (wire chase-timer rule)
- tests/enemy_brain_test.lua (extend)

## Test approach
Headless (drive with explicit dt steps): ban excludes a player from targeting and expires after its duration; robot chase clock accumulates only while that player is the target, triggers ban at threshold, resets on target switch; no-valid-target yields a wander decision; nearest-valid selection skips banned players. Manual (two players): let the robot chase P1 for 10s — it peels off to P2; with one player it wanders after the ban until the ban expires.

## Acceptance criteria
- [ ] After ~10s chasing one player, the robot bans them for ~30s and targets the other player.
- [ ] Banned players are never selected as targets until the ban expires.
- [ ] With no valid target, the enemy wanders near its position and resumes chasing when a target becomes valid.
- [ ] Durations are tunable with Tiled property overrides.
- [ ] Headless tests pass via ./test.sh.

## Blocked by
01
