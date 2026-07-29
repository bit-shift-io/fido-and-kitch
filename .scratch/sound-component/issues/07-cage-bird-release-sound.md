Status: done

# 07: Cage/Bird Release Sound

## What to build
Add Sound component to Cage entity with bird release sound. Trigger when cage opens (key collected, cage unlocks).

## Files to create/modify
- src/entities/cage.lua — add Sound component
- res/sfx/cage_open.wav

## Test approach
Integration test: load cage fixture with key, collect key, verify cage open sound plays.

## Acceptance criteria
- [ ] Cage has Sound component with open sound
- [ ] Sound plays when cage unlocks/opens
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist