Status: done

# 12: Teleport Sound

## What to build
Add Sound component to Teleport entity with entry and exit sounds. Trigger when player enters teleport and when they appear at destination.

## Files to create/modify
- src/entities/teleport.lua — add Sound component
- res/sfx/teleport_in.wav, res/sfx/teleport_out.wav

## Test approach
Integration test: load linked teleport pair, simulate player entry, verify in sound at source and out sound at destination.

## Acceptance criteria
- [ ] Teleport has Sound component with in/out sounds
- [ ] Entry sound plays at source teleport
- [ ] Exit sound plays at destination teleport
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist