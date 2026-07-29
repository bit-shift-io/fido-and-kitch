Status: done

# 09: Jump Pad Sound

## What to build
Add Sound component to JumpPad entity with launch sound. Trigger when player lands on pad and gets launched.

## Files to create/modify
- src/entities/jump_pad.lua — add Sound component
- res/sfx/jump_pad.wav

## Test approach
Integration test: load jump pad fixture, simulate player landing, verify launch sound plays.

## Acceptance criteria
- [ ] JumpPad has Sound component with launch sound
- [ ] Sound plays when player launched
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist