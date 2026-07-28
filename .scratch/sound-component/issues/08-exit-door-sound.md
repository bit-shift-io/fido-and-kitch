Status: pending

# 08: Exit Door Open Sound

## What to build
Add Sound component to ExitDoor entity with open sound. Trigger when all birds released and door opens.

## Files to create/modify
- src/entities/exit_door.lua — add Sound component
- res/sfx/exit_door_open.wav

## Test approach
Integration test: load exit door fixture with cages, release all birds, verify door open sound plays.

## Acceptance criteria
- [ ] ExitDoor has Sound component with open sound
- [ ] Sound plays when door opens (actor_count reaches 0)
- [ ] Integration test passes

## Blocked by
01 — Sound component must exist