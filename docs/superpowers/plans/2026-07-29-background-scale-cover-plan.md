# Background Scale-to-Cover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scale 1920×1080 background image layers from TMX files to cover the level map bounds (map width × map height in pixels), centered on screen, while preserving per-layer parallax factors.

**Architecture:** Pre-compute fit-to-cover scale and centered base position per background layer in `Map:new()`. In `Map:draw2()`, apply parallax offset + pre-computed base position, draw once per layer at computed scale. Reuses existing `mapParallax.computeLayerOffset()` math unchanged.

**Tech Stack:** LuaJIT, LÖVE 12.0, STI (lib/sti), bump physics, hump.class, hump.camera, Slab UI

---

## Global Constraints

- Follow existing code patterns in `src/map.lua` (hump.Class, globals like `map`, `world`, `camera`)
- Components attach via `self:addComponent()`, entities use `queueRemove()`/`queueDestroy()`
- State machines in `src/components/state_machine.lua` accept `states` (instances) or `stateClasses`
- New map entity = `src/entities/<type>.lua` + Tiled object with matching `type`; `Map.typeIgnores = {'', 'spawn'}`
- Physics via `Collider`/`World` abstraction; set `collider.walkable = true` for standable entity colliders
- Run `./test-unit.sh` for logic changes; `./test-integration.sh` for map-loaded gameplay; `./test-e2e.sh` for visual verification
- Match nearby style (mixed quotes/indentation); keep changes small; prefer new entities/components/states over growing `game_states.lua`

---

## File Structure

| File | Responsibility |
|------|----------------|
| `src/map.lua` | **Only file modified** — `Map:new()` pre-computes bg layer constants; `Map:draw2()` draws scaled backgrounds |

No new files created.

---

### Task 1: Pre-compute Background Layer Constants in Map:new()

**Files:**
- Modify: `src/map.lua:134-142` (after `backgroundMap` load)
- Test: `tests/integration/all_maps_load_test.lua` (loads maps with backgrounds)

**Interfaces:**
- Consumes: `self.map` (STI map with `width`, `height`, `tilewidth`, `tileheight`), `self.backgroundMap` (STI map with `layers` array of `imagelayer` with `image`, `parallaxx`, `parallaxy`, `offsetx`, `offsety`)
- Produces: Per-layer fields `_bgScale`, `_bgDrawW`, `_bgDrawH`, `_bgBaseX`, `_bgBaseY` on each `imagelayer` table

- [ ] **Step 1: Write failing unit test**

Create `tests/unit/background_scale_test.lua`:
```lua
local Map = require('src.map')
local Tmx = require('src.map.tmx')
local utils = require('src.utils.utils')

-- Mock minimal love.graphics for image loading
local lg = love.graphics
local originalNewImage = lg.newImage
local mockImages = {}

function lg.newImage(path)
    if not mockImages[path] then
        mockImages[path] = {
            getWidth = function() return 1920 end,
            getHeight = function() return 1080 end,
            setFilter = function() end
        }
    end
    return mockImages[path]
end

local function makeMockMap(mapW, mapH, tileW, tileH)
    return {
        width = mapW,
        height = mapH,
        tilewidth = tileW,
        tileheight = tileH,
        properties = { background = 'test_bg' },
        layers = {},
        tilesets = {},
        objects = {}
    }
end

local function makeMockBgLayer(name, parallaxx, parallaxy, offsetx, offsety)
    return {
        type = 'imagelayer',
        name = name,
        visible = true,
        opacity = 1,
        parallaxx = parallaxx or 1,
        parallaxy = parallaxy or 1,
        offsetx = offsetx or 0,
        offsety = offsety or 0,
        repeatx = false,
        repeaty = false,
        image = lg.newImage('dummy.png')
    }
end

-- Test: scale-to-cover constants computed correctly
local function test_bg_scale_computed()
    -- Level map: 20x20 tiles * 32px = 640x640
    -- BG image: 1920x1080
    -- Expected scale = max(640/1920, 640/1080) = max(0.333, 0.593) = 0.593
    -- Expected drawW = 1920 * 0.593 = 1138, drawH = 1080 * 0.593 = 640
    -- Expected baseX = (640 - 1138)/2 = -249, baseY = (640 - 640)/2 = 0
    
    local map = makeMockMap(20, 20, 32, 32)
    map.layers[1] = makeMockBgLayer('bg', 0, 0, 0, 0)
    
    local bgMap = {
        width = 30, height = 20, tilewidth = 32, tileheight = 32,
        layers = { map.layers[1] },
        tilesets = {},
        properties = {}
    }
    
    -- Mock loadSti to return our bgMap
    local originalLoadSti = package.loaded['src.map'].loadSti
    package.loaded['src.map'].loadSti = function() return bgMap end
    
    local m = Map:new('dummy.lua', nil, false)
    
    local layer = m.backgroundMap.layers[1]
    local expectedScale = math.max(640/1920, 640/1080)
    local expectedDrawW = 1920 * expectedScale
    local expectedDrawH = 1080 * expectedScale
    local expectedBaseX = (640 - expectedDrawW) / 2
    local expectedBaseY = (640 - expectedDrawH) / 2
    
    assert(math.abs(layer._bgScale - expectedScale) < 0.001, 
        string.format('scale: got %f, expected %f', layer._bgScale, expectedScale))
    assert(math.abs(layer._bgDrawW - expectedDrawW) < 0.001,
        string.format('drawW: got %f, expected %f', layer._bgDrawW, expectedDrawW))
    assert(math.abs(layer._bgDrawH - expectedDrawH) < 0.001,
        string.format('drawH: got %f, expected %f', layer._bgDrawH, expectedDrawH))
    assert(math.abs(layer._bgBaseX - expectedBaseX) < 0.001,
        string.format('baseX: got %f, expected %f', layer._bgBaseX, expectedBaseX))
    assert(math.abs(layer._bgBaseY - expectedBaseY) < 0.001,
        string.format('baseY: got %f, expected %f', layer._bgBaseY, expectedBaseY))
    
    package.loaded['src.map'].loadSti = originalLoadSti
    lg.newImage = originalNewImage
    print('test_bg_scale_computed: PASS')
end

-- Test: multiple layers with different parallax
local function test_multi_layer_parallax_preserved()
    local map = makeMockMap(30, 20, 32, 32) -- 960x640
    map.layers[1] = makeMockBgLayer('bg', 0.1, 0.1, 0, 0)
    map.layers[2] = makeMockBgLayer('mg', 0.5, 0.5, 10, 20)
    map.layers[3] = makeMockBgLayer('fg', 1.0, 1.0, -5, -5)
    
    local bgMap = { width=30, height=20, tilewidth=32, tileheight=32, layers=map.layers, tilesets={}, properties={} }
    package.loaded['src.map'].loadSti = function() return bgMap end
    
    local m = Map:new('dummy.lua', nil, false)
    
    for i, layer in ipairs(m.backgroundMap.layers) do
        assert(layer._bgScale ~= nil, 'layer '..i..' missing _bgScale')
        assert(layer._bgBaseX ~= nil, 'layer '..i..' missing _bgBaseX')
        assert(layer._bgBaseY ~= nil, 'layer '..i..' missing _bgBaseY')
        assert(layer._bgDrawW ~= nil, 'layer '..i..' missing _bgDrawW')
        assert(layer._bgDrawH ~= nil, 'layer '..i..' missing _bgDrawH')
    end
    
    package.loaded['src.map'].loadSti = originalLoadSti
    lg.newImage = originalNewImage
    print('test_multi_layer_parallax_preserved: PASS')
end

test_bg_scale_computed()
test_multi_layer_parallax_preserved()
```

- [ ] **Step 2: Run test to verify it fails**

```bash
./test-unit.sh tests/unit/background_scale_test.lua
```
Expected: FAIL (fields `_bgScale` etc. don't exist yet)

- [ ] **Step 3: Implement in `Map:new()`**

In `src/map.lua`, after line 139 (`self.backgroundMap = loadSti(...)`), add:
```lua
    -- Pre-compute background layer scale-to-cover constants
    if self.backgroundMap then
        local mapW = self.map.width * self.map.tilewidth
        local mapH = self.map.height * self.map.tileheight
        for _, layer in ipairs(self.backgroundMap.layers) do
            if layer.type == 'imagelayer' and layer.image then
                local imgW, imgH = layer.image:getWidth(), layer.image:getHeight()
                local s = math.max(mapW / imgW, mapH / imgH)
                layer._bgScale = s
                layer._bgDrawW, layer._bgDrawH = imgW * s, imgH * s
                layer._bgBaseX = (mapW - layer._bgDrawW) * 0.5
                layer._bgBaseY = (mapH - layer._bgDrawH) * 0.5
            end
        end
    end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
./test-unit.sh tests/unit/background_scale_test.lua
```
Expected: PASS

- [ ] **Step 5: Run integration tests**

```bash
./test-integration.sh
```
Expected: All pass (maps with backgrounds load correctly)

- [ ] **Step 6: Commit**

```bash
git add src/map.lua tests/unit/background_scale_test.lua
git commit -m "feat(map): pre-compute background scale-to-cover constants"
```

---

### Task 2: Draw Scaled Background in Map:draw2()

**Files:**
- Modify: `src/map.lua:382-411` (background drawing loop in `draw2`)
- Test: `tests/integration/all_maps_load_test.lua`, visual via `./test-e2e.sh`

**Interfaces:**
- Consumes: Pre-computed `_bgScale`, `_bgDrawW`, `_bgDrawH`, `_bgBaseX`, `_bgBaseY` on each background `imagelayer`; `mapParallax.computeLayerOffset()` returns `(px, py)`
- Produces: Single `lg.draw()` call per layer at scaled size + parallax offset

- [ ] **Step 1: Write failing integration test**

Add to `tests/integration/background_draw_test.lua`:
```lua
local Map = require('src.map')
local lg = love.graphics

-- Mock love.graphics for draw capture
local drawCalls = {}
local originalDraw = lg.draw
function lg.draw(img, x, y, r, sx, sy)
    table.insert(drawCalls, {img=img, x=x, y=y, r=r, sx=sx, sy=sy})
end

local function makeMockMap(mapW, mapH, tileW, tileH, bgName)
    return {
        width = mapW, height = mapH, tilewidth = tileW, tileheight = tileH,
        properties = { background = bgName },
        layers = {}, tilesets = {}, objects = {}
    }
end

local function makeMockBgLayer(name, parallaxx, parallaxy)
    return {
        type = 'imagelayer', name = name, visible = true, opacity = 1,
        parallaxx = parallaxx, parallaxy = parallaxy, offsetx = 0, offsety = 0,
        repeatx = false, repeaty = false,
        image = lg.newImage('dummy.png'),
        -- pre-computed (simulating Task 1 output)
        _bgScale = 0.5, _bgDrawW = 960, _bgDrawH = 540,
        _bgBaseX = -160, _bgBaseY = -270
    }
end

local function test_draw_scaled_bg()
    drawCalls = {}
    
    local map = makeMockMap(20, 20, 32, 32, 'test_bg') -- 640x640
    map.layers[1] = makeMockBgLayer('bg', 0, 0) -- parallax 0 = fixed to screen
    map.layers[2] = makeMockBgLayer('mg', 0.5, 0.5)
    
    local bgMap = { width=30, height=20, tilewidth=32, tileheight=32, layers=map.layers, tilesets={}, properties={} }
    package.loaded['src.map'].loadSti = function() return bgMap end
    
    local m = Map:new('dummy.lua', nil, false)
    
    -- Simulate draw2 with camera at center of map (320, 320), scale 1
    local screenW, screenH = 800, 600
    local cx, cy = 320, 320
    local tx = screenW/2 - cx * 1
    local ty = screenH/2 - cy * 1
    
    m:draw2(tx, ty, 1, 1)
    
    -- Layer 1 (parallax 0): px = (1-0)*320 + 0 = 320, dx = 320 + (-160) = 160
    -- Layer 2 (parallax 0.5): px = (1-0.5)*320 + 0 = 160, dx = 160 + (-160) = 0
    assert(#drawCalls == 2, 'expected 2 draw calls, got '..#drawCalls)
    assert(math.abs(drawCalls[1].x - 160) < 0.001, 'layer1 x: '..drawCalls[1].x)
    assert(math.abs(drawCalls[1].sx - 0.5) < 0.001, 'layer1 sx: '..drawCalls[1].sx)
    assert(math.abs(drawCalls[2].x - 0) < 0.001, 'layer2 x: '..drawCalls[2].x)
    assert(math.abs(drawCalls[2].sx - 0.5) < 0.001, 'layer2 sx: '..drawCalls[2].sx)
    
    lg.draw = originalDraw
    print('test_draw_scaled_bg: PASS')
end

test_draw_scaled_bg()
```

- [ ] **Step 2: Run test to verify it fails**

```bash
./test-integration.sh tests/integration/background_draw_test.lua
```
Expected: FAIL (old tiling loop still runs)

- [ ] **Step 3: Implement in `Map:draw2()`**

Replace lines 382-411 in `src/map.lua`:
```lua
		if self.backgroundMap then
			local screenW, screenH = lg.getWidth(), lg.getHeight()
			local cx, cy = mapParallax.computeCameraCenter(tx, ty, sx, sy, screenW, screenH)

			for _, layer in ipairs(self.backgroundMap.layers) do
				if layer.visible and layer.type == 'imagelayer' and layer.image and layer.opacity > 0 then
					local parallaxx = layer.parallaxx or 1
					local parallaxy = layer.parallaxy or 1
					local px, py = mapParallax.computeLayerOffset(
						cx, cy, parallaxx, parallaxy, layer.offsetx, layer.offsety)

					lg.setColor(1, 1, 1, layer.opacity)

					local img = layer.image
					-- Scale-to-cover: use pre-computed constants
					local dx = px + (layer._bgBaseX or 0)
					local dy = py + (layer._bgBaseY or 0)
					local s = layer._bgScale or 1
					lg.draw(img, dx, dy, 0, s, s)

					lg.setColor(1, 1, 1, 1)
				end
			end
		end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
./test-integration.sh tests/integration/background_draw_test.lua
```
Expected: PASS

- [ ] **Step 5: Run full integration + e2e tests**

```bash
./test-integration.sh
./test-e2e.sh
```
Expected: All pass; visually verify backgrounds cover map in e2e screenshots

- [ ] **Step 6: Commit**

```bash
git add src/map.lua tests/integration/background_draw_test.lua
git commit -m "feat(map): draw backgrounds scaled to cover map bounds"
```

---

### Task 3: Clean Up Test Files & Verify

**Files:**
- Modify: `tests/unit/background_scale_test.lua` (remove if not needed long-term)
- Modify: `tests/integration/background_draw_test.lua` (remove if not needed long-term)

- [ ] **Step 1: Remove temporary test files** (keep only if they add lasting value; otherwise delete)
```bash
rm tests/unit/background_scale_test.lua tests/integration/background_draw_test.lua
```

- [ ] **Step 2: Run full test suite**
```bash
./test-all.sh
```
Expected: All tiers pass

- [ ] **Step 3: Commit cleanup**
```bash
git add -u
git commit -m "test: remove temporary background test files"
```

---

## Self-Review Checklist

- [ ] **Spec coverage:** Both spec requirements addressed (Task 1: compute scale constants; Task 2: draw scaled)
- [ ] **No placeholders:** All test code and implementation code fully written out
- [ ] **Type consistency:** `_bgScale`, `_bgBaseX`, etc. match between Task 1 and Task 2
- [ ] **Existing tests:** `./test-integration.sh` covers map loading with backgrounds
- [ ] **Global constraints followed:** Uses existing `mapParallax`, `loadSti`, hump.Class patterns