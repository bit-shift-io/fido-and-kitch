# Sound Component — Decisions

### Q1: Scope
**Decision:** Full audio system for SFX only (entity Sound component + global registration)
- **Why:** User explicitly confirmed "Full audio system" then clarified "only game effects... component used in game entities"
- **Implication:** No music/ambience, no mixer, no pooling

### Q2: Audio format
**Decision:** WAV only
- **Why:** User selected WAV; LÖVE supports it natively; no loop metadata needed for SFX
- **Implication:** Larger files than OGG; no built-in loop points

### Q3: Music/ambience features
**Decision:** None — explicitly out of scope
- **Why:** "this is not for music/ambience, only game effects"
- **Implication:** No crossfade, layering, loop points, music manager

### Q4: Entity sound trigger mechanism
**Decision:** Component on entities — play named sounds from entity
- **Why:** User chose "Component on entities — play named sounds from the entity"
- **Implication:** Each entity owns its sounds; calls `self.sound:play('name')`

### Q5: Sound component features
**Decision:** Multiple named sounds per entity + random pitch variation (±10%)
- **Why:** User selected both; pitch variation prevents repetition fatigue
- **Implication:** `play()` adds `love.math.random(-0.1, 0.1)` to pitch

### Q6: Sound data source
**Decision:** Hardcoded in entity Lua files
- **Why:** User chose "Hardcoded in entity Lua files"
- **Implication:** Each entity defines `sounds = { name = 'path' }` in its init; no Tiled integration

### Q7: Source pooling
**Decision:** No pooling — create Source on each play
- **Why:** User chose "No pooling — create Source on each play"
- **Implication:** Simpler code; acceptable for low-frequency SFX; GC handles cleanup

### Q8: Trigger mechanism detail
**Decision:** Direct method calls from state machine `enter()`/`update()` and component callbacks
- **Why:** Fits existing codebase patterns (see `PlayerStates`, `Timeline`, `Pickup`, `Usable`); signals exist but not used for per-frame gameplay events
- **Implication:** `self.entity.sound:play('jump')` in `FallState:enter()` etc.; `Pickup` component calls on pickup; `Timeline` finishSignal could trigger

### Q9: Component global registration
**Decision:** Add `Sound = require('src.components.sound')` to `src/main.lua` globals
- **Why:** Consistent with `Collider`, `Sprite`, `StateMachine`, etc. in `main.lua`
- **Implication:** All files can reference `Sound` directly

### Q10: Sound file locations
**Decision:** `res/sfx/` directory (new), referenced by entity files
- **Why:** Conventional; mirrors `res/img/`; keeps assets out of source
- **Implication:** `res/sfx/coin_pickup.wav`, `res/sfx/player_jump.wav`, etc.

### Q11: Pitch variation implementation
**Decision:** `source:setPitch(1 + love.math.random() * 0.2 - 0.1)` (±10%)
- **Why:** Simple, no config needed; 10% is standard for footsteps/jumps
- **Implication:** Applied per-play in `Sound:play()`

### Q12: Unknown sound handling
**Decision:** Log warning via `print('Sound not found: ' .. name)`, return early
- **Why:** Fail-soft; don't crash game for missing asset during dev
- **Implication:** Typos in sound names are noisy but safe

### Q13: Component destroy
**Decision:** `Sound:destroy()` stops all playing sources owned by this component
- **Why:** Cleanup on entity removal; prevents orphaned sounds playing after entity gone
- **Implication:** Track created sources in `self.sources = {}`; stop on destroy

### Q14: Integration with Pickup component
**Decision:** `Pickup` component (on coin/key) calls `entity.sound:play('pickup')` in its pickup handler
- **Why:** `Pickup` already handles collection logic; sound is part of that event
- **Implication:** `Pickup` needs access to entity's Sound component (via `entity:getComponentByType(Sound)`)

### Q15: Integration with Timeline (drawbridge)
**Decision:** `Timeline.finishSignal` connects to sound play (open/close)
- **Why:** Drawbridge uses `Timeline` for animation; finishSignal fires at end of open/close
- **Implication:** Drawbridge entity connects `finishSignal:connect(func)` to play appropriate sound

### Q16: Player state machine sounds
**Decision:** Trigger in state `enter()` methods: `FallState:enter()` → jump, `WalkIdleState:enter()` from fall → land, `DeadState:enter()` → death
- **Why:** State transitions are the authoritative moment for these events
- **Implication:** Player entity needs Sound component; states access via `self.entity.sound`

### Q17: Step sounds while walking
**Decision:** Timer-based in `WalkIdleState:update()` — play step sound every N seconds while moving
- **Why:** Continuous movement needs repeated sound; timer avoids frame-dependent spam
- **Implication:** Add `stepTimer` to `WalkIdleState` or Player; reset on direction change/stop

### Q18: Enemy sounds (spider/robot)
**Decision:** Spider: web shoot on wrap, skitter while moving. Robot: motor hum while chasing, thud on stomp stun.
- **Why:** Enemies have distinct behaviors; sounds telegraph state
- **Implication:** Add Sound component to enemy entities; trigger from their state machines

### Q19: Kill zone sound
**Decision:** Play on player death (in `Player:die()` or `DeadState:enter()`) using kill zone's `deathType` to select sound
- **Why:** Death type varies (water, spikes, void); sound should match
- **Implication:** KillZone entity has sounds per type; Player accesses via `killZone.sound:play(deathType)`

### Q20: Pressure switch sounds
**Decision:** Play on activate (weight on) and deactivate (weight off) via `Switch` component or PressureSwitch entity
- **Why:** Audible feedback for switch state; matches visual
- **Implication:** PressureSwitch entity has `activateSound`, `deactivateSound`

### Q21: Story entity speech bubble sound
**Decision:** Play when bubble appears (on overlap + use key)
- **Why:** Draws attention to narrative element
- **Implication:** Story entity or Usable component triggers sound

### Key Assumptions
- WAV files exist at referenced paths (dev provides assets)
- Low SFX frequency makes no-pooling viable
- No concurrent sound limit issues (LÖVE default 256 sources)
- Single-threaded Lua; no audio thread concerns

### Trade-offs
- **No pooling** → simpler code, but GC pressure if many sounds play rapidly (mitigation: low SFX frequency)
- **Hardcoded paths** → easy to read, but asset moves require code changes (mitigation: stable `res/sfx/` structure)
- **Per-entity sounds** → duplication if multiple entities share sound (mitigation: acceptable for current entity count)
- **No volume control** → all SFX at full volume (future: add master SFX volume global)

### CONTEXT.md Updates
**New entries to add:**
- **Sound component** — Entity component that loads WAV files and plays them by name with random pitch variation. Attached to entities needing SFX. API: `init(props.sounds)`, `play(name)`, `destroy()`.
- **SFX (sound effect)** — Short, non-looping audio clip triggered by gameplay events (jump, pickup, death). Distinct from music/ambience. WAV format, static source.

**Boundary clarifications:**
- Sound component is not an audio mixer, music player, or spatial audio system.
- "Sound" in codebase = this component + its sources; not to be confused with `love.audio.Source`.