# Background Scale-to-Cover Design

**Date:** 2026-07-29  
**Project:** Fido and Kitch  
**Feature:** Background loading system — scale 1920×1080 TMX image layers to cover level map bounds

---

## Problem

Current background system loads a TMX file (e.g., `res/backgrounds/night_forest.tmx`) and tiles each image layer horizontally to cover the **main map's width**. The requirement is to instead **scale each 1920×1080 image to cover the entire level map bounds** (map width × map height in pixels), centered on screen, while preserving per-layer parallax factors.

---

## Current Behavior

In `Map:new()`:
```lua
self.backgroundMap = loadSti(resolveMapFile('res/backgrounds/' .. bgName))
```

In `Map:draw2()`:
- Iterates `backgroundMap.layers`
- For each `imagelayer`, computes parallax offset via `mapParallax.computeLayerOffset()`
- If `layer.repeatx`: tiles horizontally to cover `mapW` (main map width in pixels)
- Else: draws once at parallax offset

Background TMX declares its own map size (e.g., 30×20 tiles × 32px = 960×640), but the 1920×1080 images are drawn at 1× scale and tiled — they don't cover the level map.

---

## Design

### Approach: Pre-compute Scale-to-Cover Constants

**In `Map:new()`** (after loading `backgroundMap`):
```lua
local mapW = self.map.width * self.map.tilewidth
local mapH = self.map.height * self.map.tileheight

for _, layer in ipairs(self.backgroundMap.layers) do
    if layer.type == 'imagelayer' and layer.image then
        local imgW, imgH = layer.image:getWidth(), layer.image:getHeight()
        local s = math.max(mapW / imgW, mapH / imgH)  -- fit-to-cover
        layer._bgScale = s
        layer._bgDrawW, layer._bgDrawH = imgW * s, imgH * s
        layer._bgBaseX = (mapW - layer._bgDrawW) / 2
        layer._bgBaseY = (mapH - layer._bgDrawH) / 2
    end
end
```

**In `Map:draw2()`** (replace tiling loop):
```lua
local px, py = mapParallax.computeLayerOffset(cx, cy, parallaxx, parallaxy, layer.offsetx, layer.offsety)
local dx = px + layer._bgBaseX
local dy = py + layer._bgBaseY
lg.draw(layer.image, dx, dy, 0, layer._bgScale, layer._bgScale)
```

### Parallax Preserved

`mapParallax.computeLayerOffset()` returns `(1 - parallax) * cameraCenter + layer.offset` — exactly as before. The pre-computed `_bgBaseX/_bgBaseY` simply shifts the centered position; parallax delta is unchanged.

### Ignored TMX Properties

- `layer.repeatx` / `repeaty` — scale-to-cover replaces tiling
- Background TMX's own `width`/`height`/`tilewidth`/`tileheight` — irrelevant; level map bounds drive scaling

---

## Files Changed

| File | Change |
|------|--------|
| `src/map.lua` | `Map:new()`: pre-compute scale/offset constants per background layer. `Map:draw2()`: single draw call using pre-computed values. |

---

## Testing

- Existing integration tests load maps with `background` property (e.g., `sandbox.tmx` → `night_forest.tmx`)
- Run `./test-integration.sh` — maps should load and render backgrounds covering level bounds
- Run `./test-e2e.sh` — visual confirmation backgrounds scale correctly at different zoom levels

---

## Rollback Plan

Revert `src/map.lua` changes. No data migration needed (background TMX files unchanged).

---

## Future Considerations

- If background TMX needs per-layer scale override, add `scale` custom property in Tiled and read in `Map:new()`
- Parallax >1 (foreground moving faster than camera) already works via existing math
- Multiple background presets already supported via map property `background = "name"`