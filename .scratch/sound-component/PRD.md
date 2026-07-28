# Sound Component

## Problem Statement
The game currently has no audio feedback for any gameplay events. Players collect coins, jump, land, die, interact with drawbridges, switches, keys, cages, exit doors, jump pads, enemies, kill zones, teleports, ladders, pressure switches, and story entities — all silently. This makes the game feel lifeless and provides no auditory confirmation of actions, which is especially important in a local co-op puzzle-platformer where players need clear feedback.

## Solution
Implement a `Sound` component that entities can attach to play named sound effects. The component:
- Loads WAV files on entity initialization
- Provides `play(name)` method with random pitch variation (±10%)
- Is attached to entities that need sounds (Coin, Player, Drawbridge, Switch, Key, Cage, ExitDoor, JumpPad, Spider, Robot, KillZone, Teleport, Ladder, PressureSwitch, Story)
- Uses no source pooling — creates a new Source on each play (acceptable for low-frequency SFX)
- Integrates with existing entity/component patterns and state machines

## User Stories
1. As a player, I want to hear a sound when I collect a coin, so I know the pickup registered.
2. As a player, I want to hear a jump sound when I press jump, so I get immediate feedback.
3. As a player, I want to hear a land sound when I hit the ground, so I know I'm grounded.
4. As a player, I want to hear step sounds while walking, so movement feels tactile.
5. As a player, I want to hear a death sound when I die, so the failure is clear.
6. As a player, I want to hear the drawbridge lower and raise, so I know when it's safe to cross.
7. As a player, I want to hear a switch toggle sound, so I know my input activated it.
8. As a player, I want to hear a key pickup sound, so I know I collected it.
9. As a player, I want to hear the cage open when I unlock it, so I know progress happened.
10. As a player, I want to hear the exit door open, so I know the level can be completed.
11. As a player, I want to hear the jump pad launch sound, so the boost feels impactful.
12. As a player, I want to hear spider web shoot and wrap sounds, so I understand the threat.
13. As a player, I want to hear the robot motor and stomp sounds, so I can track it audibly.
14. As a player, I want to hear a splash/spike sound when I hit a kill zone, so the hazard type is clear.
15. As a player, I want to hear teleport entry/exit sounds, so I know where I'll appear.
14. As a player, I want to hear a sound when mounting a ladder, so the transition is clear.
15. As a player, I want to hear a sound when sliding on a ladder, so movement is confirmed.
16. As a player, I want to hear a sound when a pressure switch activates/releases, so I know its state.
17. As a player, I want to hear a sound when a story speech bubble appears, so I notice it.

## Implementation Decisions
- **Module**: `src/components/sound.lua` — new component following existing pattern
- **Global registration**: Add `Sound = require('src.components.sound')` in `src/main.lua`
- **Entity integration**: Entities add via `self:addComponent(Sound{ sounds = { jump = 'res/sfx/jump.wav', ... } })`
- **Trigger mechanism**: Direct method calls from state machine `enter()`/`update()` and component callbacks (e.g., `Pickup`, `Usable`, `Timeline`)
- **Pitch variation**: `love.math.random(-0.1, 0.1)` added to base pitch 1.0 on each play
- **File format**: WAV only (per requirements), loaded via `love.audio.newSource(path, 'static')`
- **No pooling**: Each `play()` creates a new Source; GC handles cleanup
- **Sound paths**: Hardcoded in each entity's Lua file (e.g., `coin.lua` defines its own sound table)
- **Component API**:
  ```lua
  Sound = Class{}
  function Sound:init(props)  -- props.sounds = { name = 'path', ... }, props.pitchVariation = 0.1
  function Sound:play(name)   -- clones source, sets pitch, plays
  function Sound:destroy()    -- stops all sources (optional)
  ```

## Testing Decisions
- **Unit tests** (`tests/unit/components/sound.unit.test.lua`): mock `love.audio.newSource`, verify source creation, pitch variation math, unknown sound warning
- **Integration tests** (one per entity type, issues 02–15): load fixture map, simulate trigger, capture `sound:play` calls via mock
- **Test tier**: unit for component logic; integration for entity-sound wiring; no E2E needed (no visual component)
- **Prior art**: `tests/unit/components/collider.unit.test.lua`, `tests/integration/` fixture pattern

## Out of Scope
- Music/ambience system (global, crossfading, looping)
- Source pooling / voice management (256 source limit)
- 3D/positional audio (stereo panning, distance attenuation)
- Sound randomization per entity (e.g., multiple footstep variants)
- Volume controls / mixer (master, SFX, music sliders)
- Audio ducking / priority system
- Looping sounds with intro/loop/outro segments
- Sound scripting in Tiled (all hardcoded in Lua)

## File Structure
```
src/components/sound.lua           # New component
src/main.lua                       # Add Sound global require
src/entities/coin.lua              # Add Sound component
src/player/player.lua              # Add Sound component
src/player/player_states.lua       # Trigger player sounds
src/entities/drawbridge/drawbridge.lua
src/entities/switch.lua
src/entities/key.lua
src/entities/cage.lua
src/entities/exit_door.lua
src/entities/jump_pad.lua
src/entities/spider.lua (or similar)
src/entities/robot.lua (or similar)
src/entities/kill_zone.lua
src/entities/teleport.lua
src/entities/ladder.lua (or Player)
src/entities/story.lua (or similar)
res/sfx/                           # New directory for WAV files
tests/unit/components/sound.unit.test.lua
tests/integration/fixtures/        # Per-entity sound test maps
```

## Acceptance Criteria
- [ ] Sound component loads WAV files on init
- [ ] `play(name)` works with pitch variation ±10%
- [ ] Unknown sound name logs warning, no error
- [ ] Coin plays pickup sound on collection
- [ ] Player plays jump, land, step, death sounds
- [ ] Drawbridge plays open/close sounds
- [ ] Switch plays toggle on/off sounds
- [ ] Key plays pickup sound
- [ ] Cage plays open sound
- [ ] Exit door plays open sound
- [ ] Jump pad plays launch sound
- [ ] Spider plays web/wrap/skitter sounds
- [ ] Robot plays motor/stomp sounds
- [ ] Kill zone plays death-type sound
- [ ] Teleport plays entry/exit sounds
- [ ] Ladder plays mount/slide sounds
- [ ] Story entity plays bubble sound
- [ ] All unit tests pass (`./test-unit.sh`)
- [ ] All integration tests pass (`./test-integration.sh`)

## References
- CONTEXT.md: Entity, Component, StateMachine, Signal patterns
- docs/adr/0003-multi-file-entity-directories.md (drawbridge structure)
- src/components/collider.lua (component pattern reference)
- src/player/player_states.lua (state machine trigger pattern)