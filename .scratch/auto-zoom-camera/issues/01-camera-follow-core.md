Status: pending

# Camera follow core: frame all players (no smoothing yet)

## What to build

Playing a level, the camera automatically frames all players instead of showing the whole map: zoomed in when they're close (never closer than a 5×5-tile view), zooming out as they separate (up to the full-map view), with ~2 tiles of margin around them, always clamped to map bounds with black beyond the edges. Camera movement snaps directly to the computed view this slice — smoothing comes in issue 02.

Build a pure-Lua camera module (no LÖVE dependencies in the framing math) that:
- takes N framing targets (world-space rects), map pixel size, screen size, and options (marginTiles=2, minViewTiles=5, tile size)
- returns a view (centre x/y + scale, or equivalently tx/ty/s for `Map:draw2`)
- implements: union bbox → margin → min-view clamp → aspect-ratio fit (min of x/y fit) → map-bounds clamp (centre on an axis when the view exceeds the map on that axis)
- exposes current centre and zoom for other systems to query

Wire it into the in-game state: collect player collider bounds each update, compute the view, and pass it to the map draw call instead of the fit-to-screen values. Remove or bypass the unused `hump.camera` instance. HUD/menu drawing stays screen-space and unaffected.

## Files to create/modify

- src/camera.lua (new)
- src/game_states.lua (InGameState: update/draw/resize wiring, drop unused hump camera)
- src/map.lua (allow draw with externally supplied view; keep fit-to-screen math available as the "full map view")
- tests/camera_test.lua (new)

## Test approach

Headless tests via `./test.sh` on the framing math: single target → 5×5 min view centred on it; two distant targets → both inside view with 2-tile margin; targets near a map corner → view clamped to map bounds; targets spread wider than the map → full-map framing with axis centring; wide-vs-tall boxes → aspect fit picks the min scale. Manual verification: run the game, walk players together/apart, confirm framing and black edges.

## Acceptance criteria

- [ ] Two players close together: zoomed-in view, at least 5×5 tiles visible
- [ ] Players far apart: both on screen with ~2 tiles margin
- [ ] View never shows outside the map when the map is larger than the view; black beyond edges otherwise
- [ ] HUD/menus unaffected by camera transform
- [ ] Camera centre and zoom queryable per frame
- [ ] Headless framing tests pass via `./test.sh`

## Blocked by

None — can start immediately.
