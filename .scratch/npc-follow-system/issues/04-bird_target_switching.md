Status: pending

# 04: Bird Target Switching (Random P1/P2)

## What to build
Bird NPC randomly switches follow target between P1 and P2 when both players are within `switchRange`. Checked every `switchInterval` seconds. Purely visual variety.

## Files to create/modify
- Modify: `src/components/npc_follow.lua` (add switching logic for fly type)
- Modify: `src/entities/bird_npc.lua` (configure switch params)
- Test: `tests/unit/bird_switching.unit.test.lua`

## Interfaces
- Consumes: `players[1]`, `players[2]` (global), `config.switchRange`, `config.switchInterval`
- Produces: `followComponent.targetPlayerIndex` updated randomly when conditions met

## Test approach
- Unit test: mock two players at positions within range, advance time > interval, verify target changes
- Unit test: players outside range → no switch
- Unit test: one player dead → no switch to dead player
- Unit test: random distribution roughly even over many switches

## Acceptance criteria
- [ ] Timer accumulates `dt`, triggers check every `switchInterval` (default 3s)
- [ ] Check: both players exist, not dead, distance to bird < `switchRange` (default 8 tiles)
- [ ] If check passes, randomly pick 1 or 2 (equal probability), call `setTarget(newIndex)`
- [ ] No switch if only one player alive/nearby
- [ ] Timer resets after check (not after switch — prevents rapid re-switch)

## Blocked by
- Issue 01: NPCFollowComponent (needs setTarget, config)
- Issue 03: Bird NPC entity (to configure)