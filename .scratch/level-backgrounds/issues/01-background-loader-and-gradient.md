Status: pending

# Background loader, gradient entity, preset system

## What to build
A level author sets `background = "sky"` (or `"forest"`, `"cave"`) as a map custom property. On load, `Map:loadBackground(presetName)` reads the preset from `src/backgrounds/<name>.lua` and spawns all its entities. This slice establishes the loader, the preset file structure, and the gradient entity.

Preset structure (example `src/backgrounds/sky.lua`):
```lua
return {
  defaultWindX = 10,
  layers = {
    { type = "gradient", colorTop = "#87CEEB", colorBottom = "#E0F6FF", coverMap = true },
  }
}
```

Gradient entity (`src/entities/gradient.lua`): rect object with `colorTop`, `colorBottom` (hex strings), `coverMap` (bool). When `coverMap=true`, draws a full-map vertical gradient mesh. No collider. Accepts `depth` (default 1.0).

Sandbox map: add `background = "sky"` property, verify gradient renders behind all tile layers.

## Files to create/modify
- src/backgrounds/sky.lua (new preset)
- src/backgrounds/forest.lua (stub with gradient only for now)
- src/backgrounds/cave.lua (stub with gradient only for now)
- src/entities/gradient.lua (new)
- src/map.lua (add `loadBackground`, call from `Map:new`)
- res/map/sandbox.tmx (add `background` map property)
- res/map/sandbox.lua (re-export)
- tests/unit/background_loader_test.lua (new)

## Test approach
Headless: load sandbox, assert gradient entity exists with parsed colours; `coverMap=true` yields full-map bounds; no collider created; `depth` defaults to 1.0. Visual check by running the game.

## Acceptance criteria
- [ ] Sandbox shows a top-to-bottom sky gradient behind all tile layers
- [ ] `coverMap=true` fills the map regardless of entity position
- [ ] Colours come from preset (hex strings parsed to RGB)
- [ ] No physics collider is created; players are unaffected
- [ ] `depth` property parsed and stored with default 1.0
- [ ] Preset system loads `src/backgrounds/<name>.lua` by name
- [ ] Map property `background` drives preset selection

## Blocked by
None — can start immediately.