Status: pending

# 03: Player Movement Sounds

## What to build
Add Sound component to Player entity with jump, land, walk step, and death sounds. Trigger from player state machine:
- `JumpState:enter()` → play 'jump'
- `FallState` → on landing (transition to WalkIdleState) → play 'land'
- `WalkIdleState:update()` → periodically while moving → play 'step' (with timer)
- `DeadState:enter()` → play 'death'

## Files to create/modify
- src/player/player.lua — add Sound component with sound table
- src/player/player_states.lua — trigger sounds in state enter/transition
- res/sfx/player_jump.wav, res/sfx/player_land.wav, res/sfx/player_step.wav, res/sfx/player_death.wav

## Test approach
Integration test: spawn player, simulate jump input, verify jump sound; simulate landing, verify land sound; simulate death, verify death sound. Step sound: simulate walking for N frames, verify step sound plays at intervals.

## Acceptance criteria
- [ ] Player has Sound component with jump, land, step, death sounds
- [ ] Jump sound plays on jump enter
- [ ] Land sound plays on landing (FallState → WalkIdleState)
- [ ] Step sound plays periodically while walking (not idle)
- [ ] Death sound plays on death enter
- [ ] Integration tests pass

## Blocked by
01 — Sound component must exist