Status: pending

# 04: Drawbridge Open/Close Sounds

## What to build
Add Sound component to Drawbridge entity with open (lowering) and close (raising) sounds. Trigger from Drawbridge animation timeline or state changes.

## Files to create/modify
- src/entities/drawbridge/drawbridge.lua — add Sound component
- src/entities/drawbridge/drawbridge_support.lua — or wherever animation/timeline drives open/close
- res/sfx/drawbridge_open.wav, res/sfx/drawbridge_close.wav

## Test approach
Integration test: load drawbridge fixture, trigger hold zone, verify open sound; release, verify close sound. Mock audio source capture.

## Acceptance criteria
- [ ] Drawbridge has Sound component with open/close sounds
- [ ] Open sound plays when bridge starts lowering
- [ ] Close sound plays when bridge starts raising
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist