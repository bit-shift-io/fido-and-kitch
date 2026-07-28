# HANDOFF: Story Entity

## Summary
A lightweight narrative entity for environmental storytelling. Place `type="story"` objects in Tiled with a `text` property. When a player overlaps and presses Use, a speech bubble appears above the entity with the text. Bubble dismisses on walk-away. 0.5s cooldown. Co-op ready (per-player state). No player freeze, no menus, text only.

## Implementation Order

### 1. `src/entities/story.lua` — Core Entity
- Class `StoryEntity` extending `Entity`
- `init(props)`: read `props.text` (Tiled property), create sensor collider
- `update(dt)`: handle cooldown, check player overlap + use key, manage `showing` state
- `draw()`: if `showing`, render speech bubble at `camera:worldToScreen(self.x, self.y - offset)`
- Co-op: track triggering player via `self.triggeredBy = player` (supports two independent triggers)

### 2. Unit Tests
- `tests/unit/story_entity.unit.test.lua`
- Test: text property load, sensor creation, state transitions, cooldown logic

### 3. Integration Tests
- `tests/integration/story_entity.integration.test.lua`
- Test: map spawn, trigger flow, dismiss flow, co-op independence

### 4. E2E Tests
- `tests/e2e/story_entity.e2e.test.lua`
- Visual: bubble position, camera follow, multi-entity

## Architecture Notes
- **No new components** — inline state in entity (two states only)
- **Collider:** `Collider{sensor=true, solid=false, walkable=false}` on entity
- **Player detection:** In `update`, iterate `world.players` (global), check `collider:overlaps(player.collider)` and `player.usePressed`
- **Camera:** `camera:worldToScreen(self.x, self.y - self.height - 16)` for bubble anchor
- **Text rendering:** `love.graphics.printf` with wrap width ~200px, centered above entity
- **Bubble art:** Simple rounded rect + triangle pointer (love.graphics primitives), no image asset needed

## Gotchas
- `Map.typeIgnores` includes `'story'`? No — we want it loaded. Ensure not ignored.
- Player `usePressed` is consumed per-frame; check in entity `update` before it's cleared
- Co-op: two players can overlap same entity; each gets own bubble? **Decision: one bubble per entity, last trigger wins** (simpler). Or track per-player. Start with per-entity single bubble.
- Sensor collider must be added to `world.bumpWorld` (or physics world) via `Collider:init()`
- Entity `draw()` called after map draw; bubble renders on top

## Test Commands
```bash
./test-unit.sh tests/unit/story_entity.unit.test.lua
./test-integration.sh tests/integration/story_entity.integration.test.lua
./test-e2e.sh tests/e2e/story_entity.e2e.test.lua
./test-all.sh
```

## References
- PRD: `.scratch/story-entity/PRD.md`
- DECISIONS: `.scratch/story-entity/DECISIONS.md`
- Entity pattern: `src/entities/key.lua`, `src/entities/drawbridge.lua`
- Collider sensor: `src/components/collider.lua` → `Collider{sensor=true}`
- Camera: `src/camera.lua` → `Camera:worldToScreen(x, y)`
- Player use key: `src/player/player.lua` → `self.usePressed`