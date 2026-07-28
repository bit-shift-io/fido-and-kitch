Status: pending

# 14: Pressure Switch Sounds

## What to build
Add Sound component to PressureSwitch entity with press (activate) and release (deactivate) sounds. Trigger when weight applied/removed.

## Files
- src/entities/switch.lua (pressure switch is in there) — add Sound component
- res/sfx/pressure_press.wav, res/sfx/pressure_release.wav

## Test approach
Integration test: load pressure switch fixture, place push box on it, verify press sound; remove box, verify release sound.

## Acceptance criteria
- [ ] PressureSwitch has Sound component with press/release sounds
- [ ] Press sound plays when activated (weight applied)
- [ ] Release sound plays when deactivated (weight removed)
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist