Status: pending

# 02: Player Position History (Breadcrumb Trail)

## What to build
Add a circular buffer `positionHistory` to the Player entity that records timestamped positions every frame. Rabbit NPC reads this to follow the player's exact path through ladders and puzzles.

## Files to create/modify
- Modify: `src/player/player.lua` (add buffer in `init`, record in `update`)
- Test: `tests/unit/player_position_history.unit.test.lua`

## Interfaces
- Consumes: `dt`, current `x`, `y`
- Produces: `player.positionHistory` — array of `{x, y, t}` entries, max 120 (2 seconds at 60Hz)
- Accessor: `player:getPositionHistory()` → returns copy of buffer (oldest first)

## Test approach
- Unit test buffer records positions each frame
- Unit test buffer caps at 120 entries (oldest dropped)
- Unit test timestamps increment correctly
- Unit test `getPositionHistory()` returns ordered copy
- Integration: spawn rabbit, verify it reads history

## Acceptance criteria
- [ ] `positionHistory` table exists on player after `init`
- [ ] Each `update(dt)` pushes `{x=player.x, y=player.y, t=totalTime}` 
- [ ] Buffer max length 120 entries (configurable constant)
- [ ] Oldest entries removed when buffer full (circular)
- [ ] `getPositionHistory()` returns shallow copy (prevents external mutation)
- [ ] Timestamps use `love.timer.getTime()` or game time accumulator

## Blocked by
None — can start immediately