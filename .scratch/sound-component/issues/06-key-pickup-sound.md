Status: pending

# 06: Key Pickup Sound

## What to build
Add Sound component to Key entity with pickup sound. Trigger when player collects key.

## Files to create/modify
- src/entities/key.lua — add Sound component
- res/sfx/key_pickup.wav

## Test approach
Integration test: load key fixture, simulate player collision, verify pickup sound plays.

## Acceptance criteria
- [ ] Key has Sound component with pickup sound
- [ ] Sound plays on pickup
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist