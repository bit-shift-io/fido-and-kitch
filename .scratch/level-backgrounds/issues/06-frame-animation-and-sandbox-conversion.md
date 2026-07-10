Status: pending

# Frame-animation option and sandbox conversion

## What to build
Two closing pieces:

1. **Frame animation for props**: a background prop whose template/object provides a frame source (matching the existing Sprite component's conventions — templated filename sequence or spritesheet) plays that animation via the existing Sprite + Timeline components, composable with procedural motion (a prop can have frames *and* sway/shake simultaneously). Demonstrate on one sandbox prop (placeholder frames are fine).

2. **Sandbox conversion complete**: remove sandbox's old `sky` and `trees` tile layers so the new system fully owns the background; verify the level looks at least as good as before and nothing else regressed (ground/water/ladders/entities untouched).

## Files to create/modify
- src/entities/ prop base (frame-animation wiring)
- res/img/ (placeholder frame art if needed)
- res/map/sandbox.tmx + res/map/sandbox.lua (remove sky/trees tile layers; add the frame-animated prop demo)
- tests/ (extend prop tests)

## Test approach
Headless: a prop configured with frames advances its frame index over simulated time; a prop with frames + sway has both active; a prop with neither stays static. Load sandbox and assert the old `sky`/`trees` tile layers are gone while collision/ladder/game layers are intact. Visual pass in-game.

## Acceptance criteria
- [ ] Props optionally play frame animations via the existing Sprite/Timeline system
- [ ] Frame animation and procedural motion compose on one prop
- [ ] Sandbox no longer has `sky`/`trees` tile layers; background comes entirely from the new system
- [ ] Full test suite passes; gameplay in sandbox unchanged

## Blocked by
03 and 05 (all background elements in place before removing the old layers). 04 recommended first too, so the final visual pass covers everything.
