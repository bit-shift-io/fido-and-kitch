Status: pending

# Background loader + image layers

## What to build
A level author sets `background = "night_forest"` as a map custom property. On load, `Backgrounds.load(presetName)` reads the preset from `src/backgrounds/night_forest.lua` and prepares its image layers.

Preset structure (`src/backgrounds/night_forest.lua`):
```lua
return {
  defaultWindX = 10,
  layers = {
    { name = "sky",       image = "res/img/backgrounds/sky.png",       depth = 1.0, tileX = true,  tileY = false },
    { name = "mountains", image = "res/img/backgrounds/mountains.png", depth = 0.8, tileX = true,  tileY = false },
    { name = "forest",    image = "res/img/backgrounds/forest.png",    depth = 0.5, tileX = true,  tileY = false },
  },
  props = {}  -- empty for now; clouds/trees/bushes added in later issues
}
```

Backgrounds module (`src/backgrounds/loader.lua`):
- `Backgrounds.load(presetName)` — loads preset, loads images, stores layer data
- `Backgrounds.draw(tx, ty, sx, sy)` — draws all layers sorted by depth (back to front), handles horizontal tiling (`tileX`)
- `Backgrounds.update(dt)` — no-op for image layers (props handle their own update)

Map integration: in `Map:new`, after `createEntitiesFromObjectGroupLayers`, call `Backgrounds.load(self.map.properties.background)` if property exists.

Sandbox map: add `background = "night_forest"` property, verify 3 layers render behind tile layers.

## Files to create/modify
- src/backgrounds/loader.lua (new module)
- src/backgrounds/night_forest.lua (new preset)
- src/backgrounds/sky.lua, cave.lua (stubs with single layer for variety)
- src/map.lua (add Backgrounds.load call)
- res/map/sandbox.tmx (add background property)
- res/map/sandbox.lua (re-export)
- tests/unit/background_loader_test.lua (new)

## Test approach
Headless: load sandbox, assert Backgrounds.layers has 3 entries with correct images/depths; assert draw order is sky → mountains → forest (depth ascending); assert tileX tiling math produces correct repeat for map wider than image. Visual check by running the game.

## Acceptance criteria
- [ ] Sandbox loads `night_forest` preset and renders 3 image layers behind all tile layers
- [ ] Layers draw in correct depth order (sky backmost, forest frontmost)
- [ ] Horizontal tiling works (image repeats across map width)
- [ ] Map property `background` drives preset selection
- [ ] Preset system loads `src/backgrounds/<name>.lua` by name
- [ ] No physics colliders created

## Blocked by
None — can start immediately.