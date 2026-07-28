# Sound Component — Handoff

## Summary
Implement a `Sound` component for entity-triggered sound effects (SFX only). Each entity that needs audio (Player, Coin, Drawbridge, Switch, Key, Cage, ExitDoor, JumpPad, Spider, Robot, KillZone, Teleport, Ladder, Story) attaches a Sound component with a table of named WAV paths. The component provides `play(name)` with ±10% random pitch variation. No pooling, no music, no spatial audio. Triggered via direct calls from state machines (`enter()`/`update()`) and component callbacks (`Pickup`, `Timeline`, `Usable`).

## Implementation Order

### 1. Core Component (foundation)
**Issue 01**: Create `src/components/sound.lua` with `init(props.sounds, props.pitchVariation)`, `play(name)`, `destroy()`. Register `Sound` global in `src/main.lua`. Add unit tests.

### 2. Player Sounds (highest visibility)
**Issue 02**: Add Sound component to Player (`src/player/player.lua`). Define sounds: jump, land, step, death.
**Issue 03**: Trigger in `player_states.lua`: `FallState:enter()` → jump, `WalkIdleState:enter()` from fall → land, `DeadState:enter()` → death, `WalkIdleState:update()` timer → step while moving.

### 3. Pickup Entities (coin, key)
**Issue 04**: Coin (`src/entities/coin.lua`) — add Sound, play 'pickup' in `Pickup` component handler.
**Issue 05**: Key (`src/entities/key.lua`) — same pattern.

### 4. Interactive World Entities
**Issue 06**: Drawbridge (`src/entities/drawbridge/drawbridge.lua`) — connect `Timeline.finishSignal` to play 'open'/'close'.
**Issue 07**: Switch (`src/entities/switch.lua`) — play 'on'/'off' on activation.
**Issue 08**: PressureSwitch (if separate) — play activate/deactivate on weight change.
**Issue 09**: JumpPad (`src/entities/jump_pad.lua`) — play 'launch' on player contact.
**Issue 10**: Teleport (`src/entities/teleport.lua`) — play 'enter'/'exit'.

### 5. Progression Entities
**Issue 11**: Cage (`src/entities/cage.lua`) — play 'open' on unlock.
**Issue 12**: ExitDoor (`src/entities/exit_door.lua`) — play 'open' when last bird exits.

### 6. Enemies & Hazards
**Issue 13**: Spider (find/create entity) — play 'web_shoot', 'wrap', 'skitter'.
**Issue 14**: Robot (find/create entity) — play 'motor', 'stomp'.
**Issue 15**: KillZone (`src/entities/kill_zone.lua`) — play per `deathType` (water, spikes, void).

### 7. Movement & Narrative
**Issue 16**: Ladder — play 'mount' on mount align, 'slide' during slide.
**Issue 17**: Story entity (`src/entities/story.lua`) — play 'bubble' on speech bubble show.

### 8. Tests
**Issue 16**: Unit tests for Sound component (mock love.audio).
**Issues 02–17**: Integration tests per entity (fixture map, simulate trigger, verify `play` called).

## Architecture Notes
- **Component pattern**: Follows `src/components/collider.lua` — Class, `init(props)`, methods, returned.
- **Global registration**: Add `Sound = require('src.components.sound')` in `src/main.lua` line ~44.
- **Entity integration**: `self.sound = self:addComponent(Sound{ sounds = {...} })` in entity `init()`.
- **Triggering**: `self.sound:play('name')` or `entity.sound:play('name')` from state/component.
- **Pitch variation**: `source:setPitch(1 + (love.math.random() * 0.2 - 0.1))` in `play()`.
- **WAV loading**: `love.audio.newSource(path, 'static')` — static for short SFX.

## Gotchas
- **State machine access**: Player states get entity via `self.entity`; `self.entity.sound` works.
- **Pickup component**: In `src/components/pickup.lua`, the `use`/pickup callback needs to access entity's Sound component — use `entity:getComponentByType(Sound)`.
- **Timeline finishSignal**: Drawbridge creates Timeline in init; connect finishSignal after Sound component exists.
- **No love.audio in headless tests**: Unit tests must mock `love.audio.newSource`; integration tests run under `love.*` mock (tests/integration/).
- **Source cleanup**: `Sound:destroy()` should iterate `self.sources` and call `source:stop()`; clear table.

## Test Commands
```bash
./test-unit.sh                    # All unit tests
./test-unit.sh tests/unit/components/sound.unit.test.lua  # Just sound
./test-integration.sh             # All integration
./test-integration.sh tests/integration/entities/coin.integration.test.lua
./test-all.sh                     # Full suite
```

## References
- PRD: `.scratch/sound-component/PRD.md`
- Decisions: `.scratch/sound-component/DECISIONS.md`
- CONTEXT.md updates: Sound component, SFX entries
- Component pattern: `src/components/collider.lua`, `src/components/sprite.lua`
- State machine triggers: `src/player/player_states.lua`
- Drawbridge Timeline: `src/entities/drawbridge/drawbridge.lua`
- Pickup component: `src/components/pickup.lua`