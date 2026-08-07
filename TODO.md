# TODO List
A list of tasks that need to be done. Generate docs before starting each task.

## Bugs

## High Priority
- convert ladder to use a props system so they can be seen in the editor more easily. Need to ensure they are still working with climbing volumes and can be toggled on/off with switches.

## Medium Priority
- `src/entities/exit_door.lua` (`ExitDoor:checkEndGame`): if all players have left the map, trigger game over
- `src/entities/switch.lua` (`Switch:use`): sprite needs a `play()` and `play({reverse=true})` method instead of manual frameNum toggling
- `src/physics/bump/collider.lua` (`Collider:init`): shape arguments include position as first 2 values (or a circle that just needs a radius); normalize this handling
- `src/entities/jump_pad.lua`: need a way to set the tween easing on the user's pathFollow timeline (wanted `outQuad`)

## Low Priority
- `src/components/usable.lua`: take a table of item/count pairs, or use an Inventory component, to allow complex usage scenarios
- `src/components/timeline.lua` (`update`): set `playing = false` when start/end reached
- `src/entities/ladder.lua` (`createSprites`): handle resizing better
- `src/components/path.lua` (`init`): bezier curves aren't linear; iterate with a small step to generate a table, and consider using control points to reduce curviness
- procedural levels
