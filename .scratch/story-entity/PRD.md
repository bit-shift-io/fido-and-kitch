# Story Entity

## Problem Statement
Players need narrative context in levels — hints, lore, character voice — without pausing gameplay or leaving the world. Existing entities (pickups, switches, enemies) are gameplay-focused. A lightweight narrative entity lets designers place story beats directly in Tiled.

## Solution
A single `story` entity type placed in Tiled with a `text` property. When a player overlaps the entity and presses the use key, a speech bubble appears above the entity with the configured text. The bubble dismisses when the player moves away. No player freeze, no menus, no branching — just NES-style environmental storytelling.

## User Stories
1. As a **level designer**, I want to place a story entity in Tiled with a `text` property, so that I can add narrative without code changes.
2. As a **player**, I want to press the use key near a sign/statue/pillar to read its text, so I get hints or lore without stopping play.
3. As a **player**, I want the speech bubble to appear above the entity and follow it on screen, so I know which object I'm reading.
4. As a **player**, I want the bubble to disappear when I walk away, so it doesn't clutter the screen.
5. As a **player**, I want a short cooldown before I can re-read, so accidental re-triggers don't feel sticky.
6. As a **level designer**, I want to place 3–4 story entities per level with different text each, so each level has distinct narrative beats.
7. As a **player (P2 in co-op)**, I want to trigger story entities independently of P1, so both players can read at their own pace.
8. As a **developer**, I want the entity to use the existing Tiled/STI pipeline, so no new tooling is needed.

## Implementation Decisions
- **Entity type:** Single `story` entity (`src/entities/story.lua`)
- **Tiled config:** Object type `story`, property `text` (string, `\n` for newlines)
- **Physics:** Sensor collider (trigger volume), non-walkable, no collision response
- **Trigger:** Player overlaps sensor + presses use key (Right Shift / Q / Gamepad button 1)
- **Visual:** Speech bubble rendered above entity in `entity:draw()`, world-space → screen-space via camera
- **State:** Two-state inline (`idle` / `showing`) with cooldown timer
- **Dismissal:** Auto-hide when triggering player exits sensor
- **Cooldown:** 0.5s after dismiss before re-trigger allowed
- **Co-op:** Each player tracks their own trigger state independently
- **Dependencies:** `Camera:worldToScreen()`, `Player.useKeyPressed`, `Collider` sensor type

## Testing Decisions
- **Unit tests** (`tests/unit/story_entity.unit.test.lua`):
  - Entity loads text from Tiled properties
  - Sensor collider created with correct properties
  - State machine transitions: idle → showing → idle
  - Cooldown timer prevents immediate re-trigger
  - Text wrapping logic (if implemented)
- **Integration tests** (`tests/integration/story_entity.integration.test.lua`):
  - Entity spawns from map with correct text
  - Player overlap + use key → bubble shows
  - Player exits sensor → bubble hides
  - Cooldown blocks re-trigger within window
  - P1 and P2 can trigger independently
- **E2E tests** (`tests/e2e/story_entity.e2e.test.lua`):
  - Visual verification: bubble appears at correct screen position
  - Bubble follows entity when camera moves
  - Multiple entities in same level work independently

## Out of Scope
- Branching dialogue / choices
- Multi-page / typewriter text
- Quest flags or story state persistence
- Custom images/sprites per entity (text only)
- Voiceover / sound effects
- HUD/text box at screen bottom (speech bubble only)
- Camera panning to entity

## File Structure
```
src/entities/story.lua           # New entity implementation
tests/unit/story_entity.unit.test.lua
tests/integration/story_entity.integration.test.lua
tests/e2e/story_entity.e2e.test.lua
```

## Acceptance Criteria
- [ ] Tiled object `type="story"` with `text` property loads and displays correctly
- [ ] Player overlapping entity + pressing use key shows speech bubble with that text
- [ ] Bubble renders above entity in world space, follows entity on screen
- [ ] Bubble dismisses when player moves out of overlap
- [ ] 0.5s cooldown prevents immediate re-trigger
- [ ] P1 and P2 can trigger independently in co-op
- [ ] 3–4 entities per level work without interference
- [ ] Unit, integration, and e2e tests pass

## References
- `src/entities/` — existing entity pattern (key, drawbridge, etc.)
- `src/components/collider.lua` — sensor collider setup
- `src/camera.lua` — `worldToScreen()` for bubble positioning
- `src/player/` — use key input handling
- `docs/adr/0003-multi-file-entity-directories.md` — entity structure convention