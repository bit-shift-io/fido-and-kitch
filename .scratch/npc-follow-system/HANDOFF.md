# NPC Follow System — Handoff

## Summary
Replace the path-following bird with two dynamic NPC companions: **Bird NPC** (flies freely, ignores walls, raycast+steer navigation) and **Rabbit NPC** (hops behind player, follows breadcrumb trail for reliable ladder/puzzle navigation). Cages spawn NPCs based on a Tiled `spawn_type` property. All cages unlocked → exit door enabled via event bus. NPCs are purely visual (sensor colliders only), teleport to player on death/excessive distance, follow into exit.

## Implementation Order (Vertical Slices)

### 1. Core Infrastructure (do first)
- **Issue 01:** `NPCFollowComponent` — shared component with config-driven behavior (fly vs hop)
- **Issue 02:** Player position history buffer (breadcrumb trail for rabbit)
- **Why first:** Both NPCs depend on these; testable in isolation

### 2. Bird NPC (independent, good demo)
- **Issue 03:** `bird_npc.lua` entity + steering behavior
- **Issue 04:** Bird target switching (random between P1/P2)
- **Why second:** Flashy, validates steering approach, no ladder complexity

### 3. Rabbit NPC (depends on breadcrumbs)
- **Issue 05:** `rabbit_npc.lua` entity + breadcrumb following
- **Issue 06:** Rabbit ladder/puzzle navigation + player switching (nearest)
- **Why third:** Uses infrastructure from 1; more complex movement

### 4. Cage Integration (connects NPCs to game flow)
- **Issue 07:** Cage reads `spawn_type`, spawns correct NPC, emits `cage_unlocked`
- **Issue 08:** `InGameState` tracks cage count, emits `all_cages_unlocked`
- **Issue 09:** Exit door listens for `all_cages_unlocked`, becomes usable
- **Why fourth:** Completes the gameplay loop; testable end-to-end

### 5. Polish & Edge Cases
- **Issue 10:** NPC teleport/blink on player respawn / excessive distance
- **Issue 11:** Unit + integration tests for all above
- **Why last:** Depends on all entities working

## Key Files to Touch
| File | Purpose |
|------|---------|
| `src/components/npc_follow.lua` | **NEW** Shared follow logic (steering for bird, breadcrumb for rabbit) |
| `src/entities/bird_npc.lua` | **NEW** Bird entity: sprite, sensor collider, NPCFollowComponent(fly) |
| `src/entities/rabbit_npc.lua` | **NEW** Rabbit entity: sprite, sensor collider, NPCFollowComponent(hop) |
| `src/entities/cage.lua` | **MODIFY** Read `spawn_type`, instantiate correct NPC, emit event |
| `src/player/player.lua` | **MODIFY** Add `positionHistory` circular buffer (max 120 frames) |
| `src/map/entity_factory.lua` | **MODIFY** Register `bird_npc`, `rabbit_npc` types |
| `src/states/ingame_state.lua` | **MODIFY** Listen `cage_unlocked`, track count, emit `all_cages_unlocked` |
| `src/entities/exit_door.lua` | **MODIFY** Listen `all_cages_unlocked`, set `usable=true` |
| `tests/unit/` | **NEW** Unit tests for component, both NPCs, cage, position history |
| `tests/integration/` | **NEW** Full flow: unlock cage → NPC follows → exit opens |

## Gotchas & Tips
- **Global `world`/`camera`/`players`** — available in `src/main.lua`; NPCs can access `players[1]`, `players[2]` directly
- **EventBus** — `EventBus.on("cage_unlocked", fn)` in `ingame_state.lua`; `EventBus.emit("cage_unlocked", data)` in cage
- **Sensor colliders** — `collider.isSensor = true`, no `walkable` flag; add to world but no collision response
- **Player index** — P1 = `players[1]`, P2 = `players[2]`; check `player and not player.isDead` before following
- **Delta time** — all movement in `update(dt)`; use `dt` for frame-rate independence
- **Teleport blink** — simple alpha tween: `npc.alpha = 0`, `Tween(0.2, npc, {alpha=1})` (Slab/Tween available globally)
- **Tiled property** — `object.properties.spawn_type` (string); default to "bird" if missing/nil
- **Level counter** — `InGameState` counts cages on map load: `#map:getEntitiesByType("cage")`

## Test Commands
```bash
# Unit tests (headless, fast)
./test-unit.sh tests/unit/npc_follow.component.unit.test.lua
./test-unit.sh tests/unit/bird_npc.unit.test.lua
./test-unit.sh tests/unit/rabbit_npc.unit.test.lua
./test-unit.sh tests/unit/cage.unit.test.lua

# Integration (headless, real map loading)
./test-integration.sh tests/integration/npc_follow_flow.integration.test.lua

# E2E (headed, visual)
./test-e2e.sh tests/e2e/npc_follow_visual.e2e.test.lua --paced
```

## Links
- PRD: `.scratch/npc-follow-system/PRD.md`
- Decisions: `.scratch/npc-follow-system/DECISIONS.md`
- Issues: `.scratch/npc-follow-system/issues/01-*.md` through `11-*.md`