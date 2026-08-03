# Key Color Tint System Design

## Overview
Replace per-color key sprite assets (`key_red.png`, `key_blue.png`, etc.) with a single `entity_key.png` asset, and apply color tinting at runtime via a new `Tint` component.

## Current State
- 5 key color PNGs: `key_red.png`, `key_blue.png`, `key_yellow.png`, `key_green.png`, `key_purple.png`
- `src/entities/key.lua` selects sprite via `string.format('res/img/key_%s.png', object.properties.color)`
- Tiled templates and maps reference specific color PNGs

## Target State
- Single `res/img/entity_key.png` (already exists, grayscale/white key art)
- New `Tint` component (`src/components/tint.lua`) applies RGB color at draw time
- Key entity uses `entity_key.png` + `Tint` component
- Color sourced from `object.properties.color` (string) → RGB mapping

## Components

### 1. Tint Component (`src/components/tint.lua`)
```lua
-- Props: { color = {r, g, b, a} } or { colorName = "red" }
-- In draw: love.graphics.setColor(color), sprite:draw(), love.graphics.setColor(1,1,1,1)
-- Headless: no-op
```

### 2. Key Entity Update (`src/entities/key.lua`)
- `sprite.image = 'res/img/entity_key.png'`
- Add `Tint{ colorName = object.properties.color }`

### 3. Color Mapping Table
```lua
local KEY_COLORS = {
    red    = {1, 0.2, 0.2, 1},
    blue   = {0.2, 0.4, 1, 1},
    yellow = {1, 0.9, 0.2, 1},
    green  = {0.2, 0.8, 0.3, 1},
    purple = {0.7, 0.3, 1, 1},
}
```

## Tiled/Template Updates
| File | Change |
|------|--------|
| `res/tilesets/props.tsx` | Tile id=4: `key_blue.png` → `entity_key.png` |
| `res/templates/key.tx` | `key_black.png` → `entity_key.png` |
| `res/map/sandbox.tmx` | Key objects: `key_yellow.png` → `entity_key.png` |

## Testing
- Unit test: `Tint` component applies color in headless mode (no-op, no error)
- Integration test: Key entity loads with correct tint color from map property
- E2E: Visual verification of colored keys in-game

## Files to Modify
1. `src/components/tint.lua` (new)
2. `src/entities/key.lua`
3. `res/tilesets/props.tsx`
4. `res/templates/key.tx`
5. `res/map/sandbox.tmx`

## Files to Remove (after verification)
- `res/img/key_red.png`
- `res/img/key_blue.png`
- `res/img/key_yellow.png`
- `res/img/key_green.png`
- `res/img/key_purple.png`