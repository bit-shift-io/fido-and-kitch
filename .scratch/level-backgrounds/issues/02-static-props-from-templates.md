Status: pending

# Static background props placed from templates

## What to build
A level author can drag a tree or bush template into the `background` layer and see the actual art at actual size in the Tiled editor; in-game the prop draws at that position, behind gameplay, with no collision. This slice establishes the prop entity (image from the props tileset / template, `depth`, `windScale` properties parsed) with no motion yet.

Includes: placeholder bush PNG created in-repo, `bush` (and cloud art, ready for issue 05) added as tiles to `res/tilesets/props.tsx`, new `tree.tx` and `bush.tx` templates referencing props.tsx tiles with default properties. Sandbox gets at least one tree and one bush placed in its `background` layer.

## Files to create/modify
- src/entities/tree.lua, src/entities/bush.lua (new — may share a common prop base)
- res/img/bush_1.png, res/img/cloud_1.png, res/img/cloud_2.png (new placeholder art)
- res/tilesets/props.tsx (add bush + cloud tiles)
- res/templates/tree.tx, res/templates/bush.tx (new)
- res/map/sandbox.tmx + res/map/sandbox.lua (place tree and bush)
- tests/ (new test file)

## Test approach
Headless: load sandbox, assert tree/bush entities spawn at the object positions with the right image source and parsed `depth`/`windScale`; assert no colliders. Editor check: opening sandbox.tmx in Tiled shows real tree/bush art. Visual check in-game.

## Acceptance criteria
- [ ] Tree and bush templates show actual art in the Tiled editor
- [ ] Props render in-game at their placed positions, behind gameplay layers
- [ ] Props never collide with players
- [ ] `depth` and `windScale` parsed with sensible defaults
- [ ] Placeholder bush and cloud art exists in-repo

## Blocked by
01 (background layer convention and non-collider plumbing).
