Status: pending

# 11: Kill Zone / Hazard Sounds

## What to build
Add Sound component to KillZone entity with death-type-specific sounds (water splash, spikes, lava, etc.). Trigger when player touches kill zone.

## Files to create/modify
- src/entities/kill_zone.lua — add Sound component, use deathType property for sound selection
- res/sfx/kill_water.wav, res/sfx/kill_spikes.wav, res/sfx/kill_lava.wav

## Test approach
Integration test: load kill zone fixture with deathType='water', simulate player touch, verify water sound plays.

## Acceptance criteria
- [ ] KillZone has Sound component with death-type sounds
- [ ] Correct sound plays based on kill zone's deathType property
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist