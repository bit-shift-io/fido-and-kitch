Status: pending

# 03: Bird NPC Entity

## What to build
`bird_npc.lua` entity that spawns from cage, adds `NPCFollowComponent` with `movementType="fly"`, sprite, and sensor collider. Flies freely ignoring all collision.

## Files to create/modify
- Create: `src/entities/bird_npc.lua`
- Modify: `src/map/entity_factory.lua` (register "bird_npc")
- Test: `tests/unit/bird_npc.unit.test.lua`

## Interfaces
- Consumes: `x`, `y` (spawn position), `spawnType` from cage
- Produces: Entity with components: `Sprite` (static bird image), `Collider` (sensor, 16x16), `NPCFollowComponent` (fly config)
- Entity method: `entity:onSpawn(targetPlayerIndex)` — called by cage after creation

## Test approach
- Unit test entity creation: has correct components, collider is sensor
- Unit test `onSpawn` sets follow component target
- Unit test collider added to world as sensor, no `walkable` flag
- Integration: spawn in test map, verify follows player via component

## Acceptance criteria
- [ ] Entity class extends `Entity`, calls `Entity.init(self)`
- [ ] Adds `Sprite` with bird image (asset: `res/sprites/npc/bird.png` or placeholder)
- [ ] Adds `Collider` (sensor, size ~16x16), `isSensor=true`, no `walkable`
- [ ] Adds `NPCFollowComponent` with `movementType="fly"` and bird defaults
- [ ] `onSpawn(playerIndex)` calls `followComponent:setTarget(playerIndex)`
- [ ] Registered in `entity_factory.lua` under type "bird_npc"
- [ ] No collision response with tiles, players, enemies, other NPCs

## Blocked by
- Issue 01: NPCFollowComponent (needs fly behavior)
- Issue 02: Player position history (not directly, but good to have players)