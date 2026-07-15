Status: pending

# Spider wraps players in a web

## What to build
A `spider` Tiled entity on the shared enemy base (same chase/ladder/ban/wander behaviour). On overlapping its target, it wraps them:

- Player enters a new `WrappedState` in the player FSM: all movement input ignored, gravity settles them to ground (they were possibly caught mid-air), still a camera framing target, still killable by kill zones, sets the wrapped flag that makes them shove-immune (issue 03). Sets `player.wrapped` (or equivalent) for the duration.
- A web entity (placeholder quad) is spawned over the player, fading out (alpha) over the last few seconds of the ~20s (default, tunable) duration; on expiry the web is destroyed and the player returns to normal control.
- The spider immediately calls `ban(target, 30)` on the wrapped player and retargets the other player (or wanders).
- Wrapped players are excluded from every enemy's target selection while wrapped.
- If the player dies while wrapped, the web is removed and normal death/respawn flow runs; they respawn unwrapped.

## Files to create/modify
- src/entities/spider.lua (new)
- src/entities/web.lua or src/enemy/web.lua (new, runtime-spawned — must NOT be spawnable from Tiled type matching if placed under src/entities; implementer to keep it out of the map-type path or guard it)
- src/player/player_states.lua (WrappedState)
- src/player/player.lua (wrap/unwrap API, wrapped flag)
- src/enemy/enemy_brain.lua (exclude wrapped players from targeting)
- tests/ (wrap timer/expiry, targeting exclusion; extend player-facing tests where practical)

## Test approach
Headless: wrap timer expiry restores control flag; wrapped players excluded from target selection; spider ban applied on wrap. Manual (two players): get caught — frozen ~20s under a fading quad while the spider chases your partner; camera keeps framing you; step into a kill zone area while wrapped via a hazard-adjacent catch to confirm death still works; confirm the robot can't shove you while wrapped.

## Acceptance criteria
- [ ] `spider` Tiled object spawns a spider with full shared enemy behaviour.
- [ ] Overlap with a valid target freezes that player ~20s under a web quad that fades out before release.
- [ ] Wrapped player: input ignored, gravity applies, camera-framed, hazard-killable, shove-immune; death while wrapped cleans up the web.
- [ ] Spider bans the wrapped player for ~30s and immediately retargets or wanders.
- [ ] No enemy targets a wrapped player.
- [ ] Headless tests pass via ./test.sh.

## Blocked by
01, 04
