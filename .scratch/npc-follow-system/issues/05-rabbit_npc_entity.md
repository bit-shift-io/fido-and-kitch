Status: pending

# 05: Rabbit NPC Entity

## What to build
`rabbit_npc.lua` entity that spawns from cage, adds `NPCFollowComponent` with `movementType="hop"`, sprite, and sensor collider. Follows player's breadcrumb trail for reliable ladder/puzzle navigation.

## Files to create/modify
- Create: `src/entities/rabbit_npc.lua`
- Modify: `src/map/entity_factory.lua` (register "rabbit_npc")
- Test: `tests/unit/rabbit_npc.unit.test.lua`

## Interfaces
- Consumes: `x`, `y` (spawn position), target player index
- Produces: Entity with components: `Sprite` (static rabbit image), `Collider` (sensor, 16x16), `NPCFollowComponent` (hop config)
- Entity method: `entity:onSpawn(targetPlayerIndex)` — called by cage after creation
- Reads: `players[targetIndex]:getPositionHistory()` for breadcrumbs

## Test approach
- Unit test entity creation: correct components, sensor collider
- Unit test `onSpawn` sets follow target
- Unit test follow component reads player position history
- Integration: spawn in test map with ladders, verify rabbit follows up

## Acceptance criteria
- [ ] Entity class extends `Entity`, calls `Entity.init(self)`
- [ ] Adds `Sprite` with rabbit image (asset: `res/sprites/npc/rabbit.png` or placeholder)
- [ ] Adds `Collider` (sensor, size ~16x16), `isSensor=true`, no `walkable`
- [ ] Adds `NPCFollowComponent` with `movementType="hop"` and rabbit defaults
- [ ] `onSpawn(playerIndex)` calls `followComponent:setTarget(playerIndex)`
- [ ] Registered in `entity_factory.lua` under type "rabbit_npc"
- [ ] Follow component accesses `player:getPositionHistory()` for breadcrumbs

## Blocked by
- Issue 01: NPCFollowComponent (needs hop behavior)
- Issue 02: Player position history (required for breadcrumbs)