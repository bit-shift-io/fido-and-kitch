Status: pending

# 07: Cage Spawns NPC by Type + Emits Event

## What to build
Modify existing `cage.lua` to read Tiled property `spawn_type` ("bird" | "rabbit", default "bird"), instantiate the corresponding NPC entity at cage position, call `npc:onSpawn(playerIndex)`, and emit `cage_unlocked` event with count data.

## Files to create/modify
- Modify: `src/entities/cage.lua`
- Test: `tests/unit/cage_spawn.unit.test.lua`

## Interfaces
- Consumes: `object.properties.spawn_type` (from Tiled), `playerIndex` (who unlocked), global `world`, `map`
- Produces: NPC entity added to world; `EventBus.emit("cage_unlocked", {cage=self, spawnType=type, totalCages=N, unlockedCount=M})`

## Test approach
- Unit test: cage with `spawn_type="bird"` → creates bird_npc
- Unit test: cage with `spawn_type="rabbit"` → creates rabbit_npc
- Unit test: missing/invalid property → defaults to bird
- Unit test: `onUnlock(playerIndex)` spawns NPC, calls `npc:onSpawn(playerIndex)`
- Unit test: emits `cage_unlocked` with correct counts
- Integration: unlock cage in test map, verify NPC appears and follows

## Acceptance criteria
- [ ] Reads `self.spawnType = object.properties.spawn_type or "bird"` in `init`
- [ ] `onUnlock(playerIndex)` instantiates `EntityFactory.create(self.spawnType .. "_npc", x, y)`
- [ ] Calls `npc:onSpawn(playerIndex)` after creation
- [ ] Adds NPC to world (via `map:addEntity(npc)` or `world:addEntity(npc)`)
- [ ] Emits `cage_unlocked` event with: `cage` (self), `spawnType`, `totalCages` (level total), `unlockedCount` (incrementing)
- [ ] Cage disables itself after unlock (existing behavior preserved)

## Blocked by
- Issue 03: Bird NPC entity (must exist)
- Issue 05: Rabbit NPC entity (must exist)
- Issue 01/02: NPCFollowComponent + position history (for NPCs to work)