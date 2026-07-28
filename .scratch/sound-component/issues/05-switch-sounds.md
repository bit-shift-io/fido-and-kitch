Status: pending

# 05: Switch/Lever Sounds

## What to build
Add Sound component to Switch entity (lever) with toggle on/off sounds. Trigger when player uses the switch.

## Files to create/modify
- src/entities/switch.lua — add Sound component
- res/sfx/switch_on.wav, res/sfx/switch_off.wav

## Test approach
Integration test: load switch fixture, simulate player use, verify toggle sound plays. Check sound matches switch state (on vs off).

## Acceptance criteria
- [ ] Switch has Sound component with on/off sounds
- [ ] On sound plays when switch activated
- [ ] Off sound plays when switch deactivated
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist