Status: pending

# Enemy base + robot chases nearest player on X

## What to build
Place a `robot` object in a Tiled map and, at level load, a placeholder-quad enemy spawns with player-like physics (gravity, solid vs. world, can walk off edges) and walks left/right at ~70% of player walk speed to close the X gap to the nearest alive player, continuously re-evaluating which player is nearest. It stops (idles) when roughly X-aligned. No contact effects yet.

Build this as a generic enemy base (entity scaffolding + a pure-logic "enemy brain" module for targeting and horizontal movement decisions) that the spider will reuse. Read tuning values (speed) from Tiled object properties with code defaults.

## Files to create/modify
- src/entities/robot.lua (new)
- src/enemy/enemy.lua or similar shared base (new — final layout implementer's choice)
- src/enemy/enemy_brain.lua (new, pure logic: pick target, decide horizontal move)
- src/main.lua (require/global wiring if the entity pattern needs it)
- tests/enemy_brain_test.lua (new)
- res/map/sandbox map with a robot object for manual testing (optional but recommended)

## Test approach
Headless tests on the brain module: nearest-player selection (two players at varying distances; dead players excluded), horizontal decision (move left/right/idle given enemy and target X, alignment threshold), speed comes from config. Manual: `love . debug drawphysics map=<map>` — robot follows you horizontally, falls off ledges, blocked by walls, can't catch you in the open.

## Acceptance criteria
- [ ] A `robot` Tiled object spawns a placeholder-quad enemy at level load; multiple objects spawn multiple enemies.
- [ ] Enemy walks toward the nearest alive player's X at ~70 (default) and idles when aligned within a small threshold.
- [ ] Enemy has gravity, collides with world geometry, does not block or collide with players.
- [ ] `speed` Tiled property overrides the default.
- [ ] New headless tests pass via ./test.sh.

## Blocked by
None — can start immediately.
