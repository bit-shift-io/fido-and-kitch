# External Tileset Support for STI

## Problem Statement

Tiled's recommended, default workflow since 1.0 is to save tilesets to their own `.tsx` file and reference them from a map, rather than embedding them. This project's vendored map loader (`lib/sti/`, Simple Tiled Implementation) explicitly refuses this: `assert(not tileset.filename, "STI does not support external Tilesets. You need to embed all Tilesets.")`. Today the only way to keep a map loading is to enable Tiled's "Embed tilesets" export preference and re-export every time, which is easy to forget, not discoverable (it lives in Preferences → Export Options, not the export dialog), and produces a divergent, harder-to-review exported `.lua` file. It also blocks the planned Background prop feature, whose `props` tileset (`res/tilesets/props.tsx`) is a real image-collection tileset authored for exactly this external-reference workflow.

No actively-maintained alternative library solves this out of the box: Cartographer (the most-cited modern STI alternative) has the identical gap and is more dormant than STI (last commit 2020 vs. STI's 2024), and Advanced Tiled Loader supports external tilesets but has been unmaintained even longer with an explicit "move to STI instead" recommendation from its own author. Migrating away from STI would also touch every place in this codebase that reads its map/layer/tileset data shape, for a library that isn't more alive than the one already vendored.

## Solution

Patch the vendored `lib/sti/` so that when a map references an external `.tsx` tileset, STI resolves it at load time instead of asserting: parses the referenced `.tsx` (XML) file and produces a tileset table shaped identically to what STI already builds for an embedded tileset, so every downstream consumer (tile rendering, tile animation, `Map:getTileProperties`) needs no further changes. This covers both `.tsx` shapes Tiled produces: a single shared image sliced into a grid (`res/tilesets/generic_platformer_tiles.tsx`), and an image-collection tileset with one `<image>` per tile, optionally a cropped sub-region of a larger source image (`res/tilesets/props.tsx`).

XML parsing is done via a newly-vendored general-purpose library (`xml2lua`) rather than a hand-rolled parser, since a hand-rolled parser would need extending every time an unanticipated tag shows up in a real `.tsx`. Resolved tilesets are cached by file path so repeated map loads referencing the same external tileset only parse its XML once per game run. A missing/malformed `.tsx`, or a `.tsx` referencing a missing image, fails loudly at load time — a broken tileset means the tile layers depending on it are unrenderable anyway, so surfacing it immediately beats shipping a silently-broken level.

Once this lands, maps (including `sandbox.tmx`) go back to referencing tilesets externally, the normal/default Tiled workflow, and the "Embed tilesets" preference is no longer required for this project.

## User Stories

1. As a developer, I want to export a map from Tiled using its default external-tileset workflow, so that I don't need a non-obvious Preferences setting enabled just to keep the game loading.
2. As a developer, I want an external single-image tileset (like `generic_platformer_tiles.tsx`) to resolve identically to today's embedded version, so that existing maps keep rendering and colliding exactly as before.
3. As a developer, I want an external image-collection tileset (like `props.tsx`) to resolve each tile's image correctly, including tiles that crop a sub-region of a larger source image, so that the Background prop feature (and Tiled's own object-template previews) can rely on it.
4. As a developer, I want per-tile custom properties, animation frames, and collision-editor shapes in an external tileset to resolve the same way they would in an embedded one, so external tilesets are never a second-class citizen.
5. As a developer, I want a broken or missing external tileset reference to fail loudly with a clear message at load time, so a bad export or a typo'd path is caught immediately instead of shipping a map with invisible tiles.
6. As a developer, I want repeated map loads referencing the same external tileset to parse its XML only once, so level restarts and multi-level play sessions don't pay redundant XML-parsing cost.
7. As a developer, I want this behind a small, testable, pure-logic module (mirroring `PlayerMovement`/`enemy_brain` seams elsewhere in the codebase), so tileset resolution is covered by fast headless unit tests rather than only exercised by manual play.

## Implementation Decisions

- **New vendored dependency**: `xml2lua` (MIT, pure Lua 5.1+, no C bindings) under `lib/xml2lua/`, using its built-in DOM-style tree handler.
- **New pure-logic module**: `src/map/external_tileset.lua` — takes a `.tsx` file path, returns a tileset table shaped like STI's embedded-tileset representation (`image`, `imagewidth`/`imageheight`, `tilewidth`/`tileheight`, `columns`, `spacing`, `margin`, `tilecount`, per-tile `image`/region for collection tilesets, per-tile `properties`, `animation`, `objectGroup`). Pure aside from the file read and the `xml2lua` parse call, so its table-shaping logic is headless-testable against literal XML fixtures.
- **STI patch**: replace the `assert(not tileset.filename, ...)` in `lib/sti/init.lua` with a call into `external_tileset` when `tileset.filename` is present, merging the resolved fields into the tileset table before STI's existing embedded-tileset handling runs. STI's own rendering/animation/property code paths are otherwise unchanged.
- **Caching**: a path-keyed cache inside `external_tileset` (or a thin wrapper) so a second reference to the same `.tsx` path returns the previously-resolved table without re-parsing. Cache lives for the process lifetime (no invalidation needed — `.tsx` files don't change during a play session).
- **Both `.tsx` shapes supported**: grid/single-image (`columns > 0`, one shared `<image>`) and image-collection (`columns = 0`, one `<image>` per `<tile>`, each optionally cropped via `x`/`y`/`width`/`height` distinct from the source image's own dimensions — confirmed real usage in `res/tilesets/props.tsx`).
- **Per-tile metadata resolved for parity**: `<properties>`, `<animation>`, and the Tile Collision Editor's per-tile `<objectgroup>` are all parsed and carried through in the same shape STI already gives embedded tiles, even though this project's own collision model is built from map-level object layers and does not currently consume tile-level `objectGroup` data.
- **Error handling**: a missing `.tsx` file, malformed XML, or a `.tsx` referencing a missing image raises a clear, loud error at map-load time (no silent skip).
- **Tiled workflow**: `sandbox.tmx`'s tileset reference reverts to external (no "Embed tilesets" preference needed); document this in `AGENTS.md`/`CONTEXT.md` so future export don't accidentally re-embed out of habit (harmless if they do, since embedded tilesets still work, but no longer necessary).

## Testing Decisions

- The `external_tileset` module is pure-logic (aside from a file read + XML parse) and unit-tested headlessly with literal `.tsx`-shaped XML string fixtures covering: single-image resolution, image-collection resolution (including a cropped sub-region tile, mirroring `props.tsx`'s tile id `2`/`3`/`5`/`6`/`9`), per-tile properties, per-tile animation, per-tile `objectGroup`, and cache-hit behaviour (second resolution of the same path does not re-invoke the parser).
- A small dedicated fixture map + external `.tsx` pair under `tests/fixtures/` (mirroring the existing "Fixture map" convention) is loaded through the real `Map`/STI stack in the integration tier, extending the existing "every real map loads" style of test, to prove the patched STI resolves an external tileset end-to-end (not just that the pure module produces the right table shape).
- Error-path tests: a fixture referencing a missing `.tsx` and a fixture with malformed tileset XML both assert a loud failure, not a silent skip.
- Prior art: `src/enemy/enemy_brain.lua` / `tests/unit/enemy_brain_test.lua` (pure-logic seam pattern), `tests/integration/all_maps_load_test.lua` (real-map-through-real-stack pattern).
- File naming: this is a Lua project — `tests/unit/external_tileset_test.lua`, extended `tests/integration/all_maps_load_test.lua` or a new small integration test file, run via `./test-unit.sh` / `./test-integration.sh` (the doc-stale `./test.sh` referenced by some older `.scratch/` docs in this repo does not exist).

## Out of Scope

- Loading raw `.tmx` (XML) directly as the primary map format — maps are still authored via Tiled's `.lua` export; only the referenced external `.tsx` is parsed as XML.
- Migrating off STI, or evaluating/adopting Cartographer or any other Tiled-loading library.
- Wiring resolved per-tile `objectGroup` (tile collision shapes) into this project's actual collision system — it is parsed and carried through for parity with embedded tilesets only; the game's collision model continues to come from map-level object layers.
- Resolving external object **templates** (`.tx` files, e.g. `push_box.tx`) — these are a different Tiled feature from tilesets and already resolve correctly today (Tiled's Lua exporter inlines template object fields regardless of the template file's own external/embedded status).
- Any change to Tiled's "Detach templates" or "Resolve object types and properties" export preferences.
- Building or shipping the Background prop feature itself (this unblocks it; the feature remains separately planned/deferred).
- Contributing this patch upstream to `karai17/Simple-Tiled-Implementation`.

## File Structure

```
lib/
  xml2lua/                     -- new vendored dependency
  sti/
    init.lua                   -- patched: resolves tileset.filename instead of asserting
src/
  map/
    external_tileset.lua       -- new pure-logic resolver (path -> STI-shaped tileset table), with path-keyed cache
tests/
  unit/
    external_tileset_test.lua  -- new
  fixtures/
    external_tileset_room.lua  -- new fixture map referencing an external .tsx
    external_tileset_room.tsx  -- new fixture external tileset
  integration/
    all_maps_load_test.lua     -- extended, or a new sibling test file
```

## Acceptance Criteria

- [x] A map referencing an external single-image tileset (grid-based, like `generic_platformer_tiles.tsx`) loads, renders, and collides identically to today's embedded version.
- [x] A map referencing an external image-collection tileset (like `props.tsx`), including tiles that crop a sub-region of a larger source image, resolves each tile's correct image.
- [x] Per-tile custom properties on an external tileset are readable via `Map:getTileProperties`, matching embedded-tileset behaviour.
- [x] Per-tile animation frames on an external tileset animate identically to embedded-tileset animated tiles.
- [x] Per-tile `objectGroup` (Tile Collision Editor data) on an external tileset is parsed and carried through in the same shape STI gives embedded tiles.
- [x] A missing `.tsx` file, malformed tileset XML, or a `.tsx` referencing a missing image fails loudly at map-load time with a clear message.
- [x] Loading two maps (or the same map twice) that reference the same external `.tsx` path parses that file's XML only once.
- [x] `sandbox.tmx` reverts to referencing `generic_platformer_tiles.tsx` externally (no "Embed tilesets" preference needed) and still loads correctly.
- [ ] `./test-unit.sh` and `./test-integration.sh` pass, including new tests for resolution (both tileset shapes, properties, animation, objectGroup, caching) and the error paths.

## References

- `CONTEXT.md` — new glossary entries for External tileset (and this doc's terms).
- `.scratch/external-tilesets/DECISIONS.md` — grill Q&A and rationale, including the STI-vs-Cartographer research.
- `res/tilesets/generic_platformer_tiles.tsx`, `res/tilesets/props.tsx` — real fixtures grounding both tileset shapes.
- `lib/sti/init.lua` — current assertion this patch removes; existing embedded-tileset table shape this patch must match.
