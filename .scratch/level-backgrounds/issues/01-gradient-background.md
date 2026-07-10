Status: pending

# Sky gradient from a map object

## What to build
A level author can add a `background` objectgroup to a map and place a rect object with `type=gradient`, `colorTop`/`colorBottom` colour properties, and a `coverMap` boolean. When the level loads, the game draws a vertical gradient behind everything else — filling the whole map when `coverMap=true`, or just the rect's area when false. Sandbox gains a `background` layer with a full-map gradient object, visible in-game behind the existing tile layers.

Also in this slice: the shared plumbing every later slice relies on — the `background` objectgroup convention (first in layer order), background entities creating no physics colliders, and the `depth` property being read and stored (visually inert).

## Files to create/modify
- src/entities/gradient.lua (new)
- src/map.lua (only if the objectgroup/entity pipeline needs anything for non-collider, draw-first background entities)
- res/map/sandbox.tmx (add `background` objectgroup + gradient object)
- res/map/sandbox.lua (re-export)
- tests/ (new test file per existing harness conventions)

## Test approach
Headless: load sandbox, assert a gradient entity exists with the parsed colours; assert `coverMap=true` yields full-map bounds while a non-cover rect keeps its own; assert the entity registers no physics collider; assert `depth` is stored (defaulting to 1.0 when absent). Visual check by running the game.

## Acceptance criteria
- [ ] Sandbox shows a top-to-bottom gradient behind all tile layers
- [ ] `coverMap=true` fills the map regardless of rect size
- [ ] Colours come from Tiled colour properties on the object
- [ ] No physics collider is created; players are unaffected
- [ ] `depth` property parsed and stored with default 1.0

## Blocked by
None — can start immediately.
