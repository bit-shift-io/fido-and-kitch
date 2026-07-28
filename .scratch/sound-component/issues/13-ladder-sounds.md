Status: pending

# 13: Ladder Mount/Slide Sounds

## What to build
Add Sound component to Ladder entity (or Player) with mount (aligning to ladder) and slide sounds. Trigger from Player LadderState: mount on enter, slide during horizontal movement.

## Files to create/modify
- src/entities/ladder.lua — or add to Player's sound component
- res/sfx/ladder_mount.wav, res/sfx/ladder_slide.wav

## Test approach
Integration test: player approaches ladder, presses up, verify mount sound; hold left/right on ladder, verify slide sound.

## Acceptance criteria
- [ ] Mount sound plays when player aligns to ladder center
- [ ] Slide sound plays (looped or one-shot) while sliding horizontally on ladder
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist
03 — Player movement sounds (LadderState integration)