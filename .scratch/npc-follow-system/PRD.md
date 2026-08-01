# NPC Follow System

## Problem Statement
Currently, rescued birds follow a pre-authored spline path to fly away. This requires map makers to manually create paths for every cage in every level. We want to replace this with NPC companions (birds and rabbits) that dynamically follow players around the level, eliminating the need for authored paths while adding playful, kid-friendly companion behavior.

## Solution
Replace the path-following bird entity with two new NPC entity types — **Bird NPC** and **Rabbit NPC** — that spawn from cages when unlocked and follow players dynamically. The cage entity remains unchanged; a Tiled property on the cage specifies which NPC type spawns. Both NPCs are purely visual (no collision with players, enemies, or each other) and accompany players to the level exit.

## User Stories
1. As a **map maker**, I want to place a cage and set a property to spawn either a bird or rabbit NPC, so I don't have to author spline paths.
2. As a **player (P1 or P2)**, when I unlock a cage with the correct key, an NPC spawns and follows me, so I feel rewarded for solving the puzzle.
3. As a **player**, the bird NPC flies/hovers around me and the other player, ignoring walls and obstacles, so it feels like a free-flying companion.
4. As a **player**, the rabbit NPC hops close behind me, follows me up ladders and across puzzle elements, so it feels like a loyal pet.
5. As a **player in co-op**, when both players are near each other, the rabbit may switch to follow the other player, so the companion feels shared.
6. As a **player**, the bird randomly switches between following P1 and P2 when they're close, so it feels playful and unpredictable.
7. As a **player**, when I die or respawn, my NPC companions teleport/blink to me so they're never lost.
8. As a **player**, when all cages in a level are unlocked, the exit door becomes usable, so I can complete the level with my rescued companions.
9. As a **player**, NPCs follow me into the exit door and are "rescued" with me, giving a satisfying conclusion.

## Implementation Decisions
- **Modules built or modified:**
  - New: `src/entities/bird_npc.lua`, `src/entities/rabbit_npc.lua` — NPC entity implementations
  - Modify: `src/entities/cage.lua` — read Tiled property to determine spawn type, emit event on unlock
  - Modify: `src/map/entity_factory.lua` — register new entity types
  - New: `src/components/npc_follow.lua` — shared follow behavior component (steering for bird, path-following for rabbit)
  - Modify: `src/states/ingame_state.lua` — listen for "all cages unlocked" event to enable exit door
  - Modify: Exit door entity (likely `src/entities/exit_door.lua` or similar) — check event/flag for usability
  - Use: `src/utils/event_bus.lua` — for "cage_unlocked" and "all_cages_unlocked" events

- **Interfaces and signatures:**
  - `NPCCage.spawnType` (string): "bird" | "rabbit" — set via Tiled property `spawn_type`
  - `NPCFollowComponent:init(entity, config)` — config: `{targetPlayer: number|"nearest"|"random", followDistance: number, movementType: "fly"|"hop"}`
  - `NPCFollowComponent:update(dt)` — handles movement logic
  - `EventBus:on("cage_unlocked", handler)` — handler receives `{cageEntity, spawnType, totalCages, unlockedCount}`
  - `EventBus:on("all_cages_unlocked", handler)` — handler enables exit door

- **Architectural decisions:**
  - NPCs are `Entity` subclasses with `Collider` (sensor-only, non-walkable), `Sprite`, and `NPCFollowComponent`
  - Bird uses raycast + steering (no pathfinding grid needed); ignores all collision
  - Rabbit follows player's recorded path positions (breadcrumb trail) for reliable ladder/puzzle navigation
  - Both NPCs teleport to player if distance exceeds threshold (e.g., 20 tiles) or on player respawn
  - Cage unlock decrements a level counter; when zero, emits "all_cages_unlocked"
  - No animation system changes — single static sprite per NPC for now

- **Schema changes:**
  - Tiled cage object: new custom property `spawn_type` (string, enum: "bird", "rabbit", default "bird")

## Testing Decisions
- **Unit tests** (headless, `tests/unit/`):
  - `bird_npc.unit.test.lua` — steering behavior, target switching, teleport logic
  - `rabbit_npc.unit.test.lua` — path-following, ladder climbing, player switching
  - `cage.unit.test.lua` — spawn type reading, event emission, counter decrement
  - `npc_follow.component.unit.test.lua` — shared component logic
- **Integration tests** (`tests/integration/`):
  - Cage unlock → NPC spawns and follows player through simple level
  - All cages unlocked → exit door becomes usable
  - Player death → NPCs teleport to safe position
  - Co-op: rabbit switches between players, bird random switches
- **E2E tests** (`tests/e2e/`):
  - Visual verification of bird flight and rabbit hop behavior
  - NPCs enter exit door with player

## Out of Scope
- Animation system for NPCs (single sprite only)
- NPC-player interaction (petting, feeding, dismissing)
- NPC collision with enemies or hazards
- NPC persistence across levels (each level independent)
- Complex bird flocking or rabbit AI beyond follow/switch
- Sound effects for NPCs

## File Structure
```
src/entities/
  bird_npc.lua
  rabbit_npc.lua
  cage.lua (modified)
src/components/
  npc_follow.lua (new)
src/map/
  entity_factory.lua (modified)
src/states/
  ingame_state.lua (modified)
src/entities/exit_door.lua (modified, if exists)
```

## Acceptance Criteria
- [ ] Cage with `spawn_type="bird"` spawns a bird NPC that flies around players
- [ ] Cage with `spawn_type="rabbit"` spawns a rabbit NPC that hops behind player
- [ ] Bird ignores walls/tiles, uses raycast+steer to follow target
- [ ] Rabbit follows player's path breadcrumbs, climbs ladders, navigates puzzles
- [ ] Bird randomly switches target between P1/P2 when both nearby
- [ ] Rabbit switches to nearest player when both within range
- [ ] NPCs teleport/blink to player on death/respawn or excessive distance
- [ ] All cages unlocked → exit door usable (via event bus)
- [ ] NPCs follow player into exit door
- [ ] No collisions between NPCs and players/enemies/tiles
- [ ] Unit tests pass for all new components and entities
- [ ] Integration test verifies full cage→NPC→exit flow

## References
- `src/entities/cage.lua` — current cage implementation
- `src/entities/bird.lua` — current path-following bird (to be replaced)
- `src/player/player_sensors.lua` — ladder/ground queries for rabbit path-following
- `src/utils/event_bus.lua` — event system
- `CONTEXT.md` — glossary terms: "cage", "spawn", "exit door", "safe position"