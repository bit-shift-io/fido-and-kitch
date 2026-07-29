Status: done

# Load a `.tmx` map with a tile layer end-to-end

## What to build

A `.tmx` file containing map attributes, an externally referenced tileset and a base64 tile layer loads through the real `Map`/STI stack and renders, without any `.lua` export existing for it. `.lua` maps continue to load exactly as before, chosen by file extension.

This is the foundation slice: the parser module, the dispatch seam, and the map-level constructs. It also establishes the two behaviours everything later depends on — emitting the exporter's table shape, and failing loudly on unsupported constructs.

**Do this first, before touching any map content:** copy the six existing Tiled exports (`res/map/{sandbox,ll1,ll2}.lua`, `res/backgrounds/{night_forest,mushroom_cave,sky}.lua`) into `tests/fixtures/golden/`. They are the reference the differential tests in issues 02–04 compare against. Once deleted in issue 06 they are only recoverable from git history, so capture them now.

Scope for this slice:

- **Map attributes** — `version`, `tiledversion`, `orientation`, `renderorder`, `width`, `height`, `tilewidth`, `tileheight`, `nextlayerid`, `nextobjectid`, plus the values the exporter synthesises rather than reads (`luaversion = "5.1"`, `class = ""`).
- **Map and layer custom properties**, with type coercion. The shared coercion helper is introduced here because map-level and layer-level properties both need it (the real maps use `bool` and untyped string properties on layers); issue 02 reuses it for objects. Cover untyped (string), `bool`, `int`, `float`, `file`, `object` (which becomes an id-bearing table) and `color`.
- **Tileset references** — `<tileset firstgid=".." source="..">` resolved through the existing `src/map/external_tileset.lua`, emitted with `filename` set so the existing STI patch takes its already-project-root-relative branch.
- **Tile layers** with base64 data, emitted **still encoded** alongside the encoding and compression markers, so STI's existing decode path handles it.
- **Default materialisation** — every value Tiled omits from XML when it equals a default must be written as the exporter writes it: `offsetx`/`offsety` `= 0`, `parallaxx`/`parallaxy` `= 1`, `opacity = 1`, `visible = true`, `x`/`y` `= 0`, `class = ""`, `properties = {}`.
- **Loud failures** — a missing or unreadable `.tmx`, malformed XML, CSV-encoded tile data, an infinite or chunked map, and an unrecognised layer type each raise an error naming the file and the specific construct.

Not in this slice: object layers (02), image layers (03), templates (04), grouped layers (05), background dispatch (03), deleting exports (06).

## Files to create/modify

- `tests/fixtures/golden/` (new — preserved copies of the six exports; do this first)
- `src/map/tmx.lua` (new — `.tmx` path → exporter-shaped map table)
- `src/map.lua` (dispatch on extension at the level-loading site; the background site is left for issue 03)
- `src/map/external_tileset.lua` (return the tileset's `name`; see gotcha below)
- `tests/fixtures/tmx/` (new — purpose-built minimal `.tmx` fixtures plus a `.tsx` for them)
- `tests/unit/tmx_test.lua` (new) and register it in `tests/unit/run.lua`
- `tests/integration/tmx_test.lua` (new) and register it in `tests/integration/run.lua`

## Test approach

**Unit (headless, literal XML strings, injected file reader).** Mirror `tests/unit/external_tileset_test.lua`'s pattern — the parser takes an injectable reader so table-shaping logic is testable without the filesystem. Assert: map attributes including the synthesised ones; each property type coerces to the value the exporter produces, and an `object`-typed property becomes an id-bearing table; tile layer data comes back still base64-encoded with its markers intact rather than decoded; omitted attributes materialise to exporter defaults; the tileset entry carries `name`, `firstgid` and a project-root-relative `filename`. Then one test per loud failure: unreadable file, malformed XML, CSV encoding, infinite map, unrecognised layer type — each asserting the message names the offending file.

Build fixture XML from the real files' structure (`res/map/ll1.tmx`, `res/tilesets/generic_platformer_tiles.tsx`) rather than a simplified form, so real Tiled quirks are exercised.

**Integration (real stack).** A purpose-built fixture `.tmx` with one tile layer and one collision object group loads via the harness and steps frames without error, and the resolved tileset carries correct image dimensions and tile geometry. Note `tiny.tmx` is **not** usable here — its tileset path is broken (see issue 06).

Also assert a hand-authored `.lua` fixture still loads unchanged, so the dispatch seam is proven not to have disturbed the existing path.

## Acceptance criteria

- [ ] The six existing exports are preserved under `tests/fixtures/golden/`.
- [ ] A `.tmx` with map attributes, an external tileset and a base64 tile layer loads through the real stack and renders.
- [ ] `.lua` maps load exactly as before; dispatch is by file extension.
- [ ] Tile layer data is emitted still base64-encoded with encoding/compression markers, and STI's existing decode path consumes it unchanged.
- [ ] All supported property types coerce correctly, including `object` becoming an id-bearing table.
- [ ] Omitted attributes materialise to the exporter's defaults.
- [ ] Missing/unreadable `.tmx`, malformed XML, CSV data, infinite/chunked maps and unrecognised layer types each raise an error naming the file and the construct.
- [ ] `patches/sti.patch` is unchanged.
- [ ] `./test-unit.sh` and `./test-integration.sh` pass.

## Implementer notes

- **`external_tileset.resolve` does not currently return `name`, and the parser needs it.** In the `.lua` export the tileset's name lives on the *map's* tileset entry, but a `.tmx`'s `<tileset source="...">` has no name attribute — the name is inside the `.tsx`. STI uses `tileset.name` as the image-collection atlas cache key, so it must be populated. Add `name` to what the resolver returns.
- **`filename` must be project-root-relative.** The existing STI patch computes the `.tsx` path as `format_path(path .. tileset.filename)`, and `path` is empty when a pre-built table is passed to STI. Emitting the raw `.tmx`-relative value (e.g. `../tilesets/x.tsx`) will not resolve. Resolve it against the `.tmx`'s own directory first, exactly as `external_tileset` already does for image paths.
- Reuse `lib/sti/utils.lua`'s `format_path` for path normalisation, as `external_tileset` does.
- Extract the XML helpers `external_tileset.lua` already has (single-child-vs-array normalisation, numeric attribute coercion, directory-of-path) rather than duplicating them — both modules need all three.
- The vendored parser is reached as `require('lib.xml2lua.xml2lua')` with the tree handler at `require('lib.xml2lua.xmlhandler.tree')`, and a fresh handler must be constructed per parse.
- Test runner scripts are `./test-unit.sh`, `./test-integration.sh`, `./test-e2e.sh`, `./test-all.sh`. Test files must be registered in their tier's manifest in `run.lua` or they silently never run.

## Blocked by

None — can start immediately.
