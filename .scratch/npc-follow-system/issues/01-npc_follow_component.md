Status: pending

# 01: NPCFollowComponent — Shared Follow Logic

## What to build
A reusable component `NPCFollowComponent` that encapsulates the movement logic for both bird and rabbit NPCs. Configuration-driven: `movementType` ("fly" | "hop") selects steering vs breadcrumb-following behavior. Handles target selection, distance maintenance, and teleport trigger.

## Files to create/modify
- Create: `src/components/npc_follow.lua`
- Test: `tests/unit/npc_follow.component.unit.test.lua`

## Interfaces
- Consumes: `entity` (has `x`, `y`, `components.sprite`, `components.collider`), `config` table
- Produces: `component:update(dt)` — moves entity toward target; `component:setTarget(playerIndex)`; `component:teleportTo(x, y)`

```lua
-- Config schema
{
  movementType = "fly" | "hop",        -- required
  followDistance = number,             -- tiles, default: fly=4, hop=2
  maxSpeed = number,                   -- tiles/sec, default: fly=120, hop=80
  teleportDistance = number,           -- tiles, default: 20
  switchRange = number,                -- tiles, default: fly=8, hop=6
  switchInterval = number,             -- seconds, bird only, default: 3
  arrivalRadius = number,              -- tiles, slow down within, default: fly=2, hop=1
}
```

## Test approach
- Unit test steering math: seek, arrival, separation
- Unit test breadcrumb following: interpolation, ladder handling
- Unit test target switching logic (mock players at positions)
- Unit test teleport trigger (distance > threshold)
- Mock `entity` with minimal `x`, `y`, `components`

## Acceptance criteria
- [ ] Component initializes with config, stores reference to entity
- [ ] `movementType="fly"`: seeks target, slows near arrival, adds separation from other birds
- [ ] `movementType="hop"`: follows breadcrumb positions, jumps at height changes/gaps
- [ ] `setTarget(playerIndex)` updates follow target
- [ ] Teleport triggers when distance to target > `teleportDistance`
- [ ] Bird: random target switch when both players in `switchRange` every `switchInterval`
- [ ] Rabbit: switches to nearest player when both in `switchRange` (with hysteresis)
- [ ] All math uses `dt` for frame-rate independence

## Blocked by
None — can start immediately