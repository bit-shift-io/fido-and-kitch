Status: pending

# Background loader + parallax image layers

## What to build
A level author sets `background = "night_forest"` as a map custom property. On load, `Backgrounds.load(presetName)` reads the preset from `src/backgrounds/night_forest.lua` and prepares its image layers with parallax.

Preset structure (`src/backgrounds/night_forest.lua`):
```lua
return {
  layers = {
    { name = "sky",       image = "res/img/backgrounds/background_night_sky.png",       depth = 0.0, parallaxFactor = 0.0, tiling = "repeat_x" },
    { name = "mountains", image = "res/img/backgrounds/midground_night_mountains.png", depth = 0.3, parallaxFactor = 0.3, tiling = "repeat_x" },
    { name = "forest",    image = "res/img/backgrounds/foreground_night_forest.png",    depth = 0.6, parallaxFactor = 0.6, tiling = "repeat_x" },
  },
}
```

Backgrounds module (`src/backgrounds/loader.lua`):
- `Backgrounds.load(presetName)` — loads preset, loads images via `love.graphics.newImage`, stores layer data sorted by `depth` ascending
- `Backgrounds.draw(cameraX, cameraY, sx, sy)` — called from `Map:draw2` before tile layers. For each layer: computes draw offset = `cameraX * (1 - parallaxFactor)`, draws image tiled horizontally to cover `mapWidth * sx`
- `Backgrounds.update(dt)` — no-op for now

Map integration: in `Map:new`, after `createEntitiesFromObjectGroupLayers`, call `Backgrounds.load(self.map.properties.background)` if property exists.

Sandbox map: add `background = "night_forest"` property, verify 3 layers render behind tile layers with parallax when camera moves.

## Files to create/modify
- src/backgrounds/loader.lua (new module)
- src/backgrounds/night_forest.lua (new preset)
- src/backgrounds/sky.lua, cave.lua (stubs with single layer for variety)
- src/map.lua (add Backgrounds.load call)
- res/map/sandbox.tmx (add background property)
- res/map/sandbox.lua (re-export)
- tests/unit/background_loader_test.lua (new)

## Test approach
Headless: load sandbox, assert Backgrounds.layers has 3 entries with correct images/depths/parallaxFactors; assert draw order is sky → mountains → forest (depth ascending); assert parallax offset formula `cameraX * (1 - parallaxFactor)`; assert tiling math covers map width. Visual check by running the game and moving camera (if possible) or inspecting draw offsets.

## Acceptance criteria
- [ ] Sandbox loads `night_forest` preset and renders 3 image layers behind all tile layers
- [ ] Layers draw in correct depth order (sky backmost, forest frontmost)
- [ ] Horizontal tiling works (image repeats across map width)
- [ ] Parallax formula: layer X = cameraX * (1 - parallaxFactor) + baseX
- [ ] Map property `background` drives preset selection
- [ ] Preset system loads `src/backgrounds/<name>.lua` by name
- [ ] No physics colliders created

## Blocked by
None — can start immediately.