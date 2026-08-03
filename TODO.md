# TODO List
A list of tasks that need to be done. Generate docs before starting each task.

## Bugs
* fix sounds - random volume, many sounds playing for character walk
* opening all cages doesnt trigger door via eventbus
* when pushing a box off the edge of a platform, the player can walk through the collision briefly
* npcs not spawning from cages when opened
* enemy npcs not spawning and their spawn point

## Review best implementation - should we or shouldnt we?
* merge pushable_props, push_box, boulder into single prop 'pushable.lua' image + behaviour (roll/slide) can be customised in tiled
* merge switch/pressure switch into a single entity with customizable image/behaviour

## High Priority
* npc refactor
* pickups (coins & lives) which work - keys work! Event bus/game state
* fix gamepad controls - back toggle camera, start exit to menu
* turn props on/off via switch - ladders, teleporter, spring pads, drawbridge etc

## Medium Priority
* particle effects
* story entity
* ladders as props?

## Low Priority
* procedural levels
* game gui/hud - coins
