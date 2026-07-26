Status: done

# Background map loader + parallax draw

## What to build
A level author sets `background = "night_forest"` as a map custom property. On load, `Map:new` loads `res/backgrounds/night_forest.lua` as a second STI map (`self.backgroundMap`). In `Map:draw2`, before drawing main map layers, draw `self.backgroundMap` layers with parallax.

Background map (`res/backgrounds/night_forest.lua`): 3 image layers with `parallaxx`/`parallaxy`:
- background (sky):       parallaxx=0.0, parallaxy=0.0
- midground (mountains):  parallaxx=0.5, parallaxy=0.5
- foreground (forest):    parallaxx=0.8, parallaxy=0.8

Parallax draw (in `Map:draw2`):
```lua
if self.backgroundMap then
  for _, layer in ipairs(self.backgroundMap.layers) do
    if layer.visible and layer.type == "imagelayer" then
      local px = math.floor(tx * (layer.parallaxx or 1))
      local py = math.floor(ty * (layer.parallaxy or 1))
      layer.repeatx = true  -- force horizontal tiling
      -- draw layer.image at (px + layer.offsetx, py + layer.offsety) tiled horizontally
    end
  end
end
```

Sandbox map: add `background = "night_forest"` property, verify 3 layers render behind tile layers with parallax.

## Files to create/modify
- src/map.lua (add background map loading in Map:new, parallax draw in Map:draw2)
- res/map/sandbox.tmx (add background property)
- res/map/sandbox.lua (re-export)
- tests/unit/background_map_test.lua (new)

## Test approach
Headless: load sandbox, assert self.backgroundMap exists with 3 imagelayers; assert parallaxx/parallaxy match TMX; assert repeatx forced true; assert parallax offset formula `math.floor(tx * parallaxx)` correct for sample tx values. Visual check by running the game.

## Acceptance criteria
- [ ] Sandbox loads `night_forest` background map as second STI map
- [ ] 3 background layers draw behind all main map tile layers
- [ ] Layers draw in correct order (sky → mountains → forest)
- [ ] Parallax works: layers move at different speeds relative to camera (verify with sample tx offsets)
- [ ] Horizontal tiling works (repeatx forced true, images repeat across map width)
- [ ] Map property `background` drives background selection
- [ ] No physics colliders created from background map

## Blocked by
None — can start immediately.