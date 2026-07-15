Status: pending

# Push box exists as a solid, standable, falling blocker

## What to build
A `push_box` prop that a designer can place in Tiled and that appears in-game as a 32×32 placeholder quad (brown). It has a dynamic collider, so it falls straight down under the existing gravity and comes to rest on solid map ground. It blocks the player (the player cannot walk through it) and the player can stand and walk on top of it as if it were solid ground. No pushing yet.

## Files to create/modify
- src/entities/push_box.lua (new — `Class{__includes = Entity}`, dynamic Collider 32×32 normal group index, placeholder quad draw)
- res/templates/push_box.tx (new — Tiled template, `type="push_box"`)
- res/map/sandbox.tmx and res/map/sandbox.lua (place one box on an objectgroup for manual demo; export .lua)
- (reference existing) src/entities/kill_zone.lua, src/entities/coin.lua for entity shape; src/physics/bump/collider.lua for collider/gravity API; src/game_states.lua / src/player/player.lua for placeholder rectangle draw pattern

## Test approach
Primarily manual/visual for this slice (a box that renders, falls, blocks, is standable). If a cheap headless assertion is available, assert the entity constructs with a dynamic collider of the expected size from a Tiled-style object table. Verify in-game: box falls to ground, player collides with its sides, player can stand on its top.

## Acceptance criteria
- [ ] A `push_box` placed in Tiled loads in-game.
- [ ] It renders as a 32×32 placeholder quad.
- [ ] It falls straight down and rests on solid ground.
- [ ] The player cannot walk through it (it blocks horizontally).
- [ ] The player can stand and walk on its top.

## Blocked by
None — can start immediately.
