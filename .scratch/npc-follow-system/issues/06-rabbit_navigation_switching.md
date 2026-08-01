Status: pending

# 06: Rabbit Ladder/Puzzle Navigation + Player Switching

## What to build
Rabbit follow behavior: interpolates along player's breadcrumb trail, jumps at height changes (ladders, steps, gaps). Switches to nearest player when both within `switchRange` (with hysteresis).

## Files to create/modify
- Modify: `src/components/npc_follow.lua` (hop behavior: breadcrumb interpolation, jump detection, player switching)
- Test: `tests/unit/rabbit_navigation.unit.test.lua`

## Interfaces
- Consumes: `player:getPositionHistory()`, `config.followDistance`, `config.maxSpeed`, `config.switchRange`, `world` (for raycast down)
- Produces: Rabbit position updated each frame following trail; `targetPlayerIndex` switches when conditions met

## Test approach
- Unit test: breadcrumb interpolation — rabbit moves toward oldest history entry within followDistance
- Unit test: jump detection — raycast down finds no ground → apply jump velocity
- Unit test: ladder — breadcrumb Y decreases (climbing) → rabbit moves up same X
- Unit test: player switching — two players at different distances, rabbit picks nearer; hysteresis prevents jitter
- Unit test: dead player excluded from switch targets

## Acceptance criteria
- [ ] Rabbit seeks oldest breadcrumb within `followDistance` (default 2 tiles) along trail
- [ ] Movement: horizontal velocity toward breadcrumb X, clamped to `maxSpeed`
- [ ] Jump: raycast down from rabbit bottom + 2px; if no hit within 1 tile → apply jump velocity (0.7x player jump)
- [ ] Ladder: breadcrumb shows Y decreasing steadily → rabbit moves up at climb speed (same as horizontal)
- [ ] Player switch check every frame: both players alive, distance to rabbit < `switchRange` (default 6 tiles)
- [ ] Hysteresis: only switch if new target distance < current target distance * 0.8 (20% closer)
- [ ] Dead players never selected as target

## Blocked by
- Issue 01: NPCFollowComponent (core structure)
- Issue 02: Player position history (breadcrumbs)
- Issue 05: Rabbit NPC entity (to configure)