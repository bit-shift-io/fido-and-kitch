Status: done

# Resolve a single-image (grid) external tileset

## What to build
A map referencing an external `.tsx` tileset that uses a single shared image sliced into a grid (`columns > 0`, one `<image>` element at the tileset level — e.g. `res/tilesets/generic_platformer_tiles.tsx`) loads, renders, and collides exactly as it would if that tileset were embedded. This is the foundation slice: vendoring `xml2lua`, creating the `external_tileset` resolver module, and patching `lib/sti/init.lua` to call it instead of asserting. Also covers the basic error path (missing `.tsx` file, malformed XML) since even this simplest shape needs to fail loudly rather than silently produce a broken tileset.

## Files to create/modify
- lib/xml2lua/ (new, vendored dependency)
- src/map/external_tileset.lua (new — pure logic: path -> STI-shaped tileset table; single-image shape only for this issue)
- lib/sti/init.lua (patch: replace `assert(not tileset.filename, ...)` with a call into `external_tileset` when `tileset.filename` is present)
- tests/unit/external_tileset_test.lua (new)
- tests/fixtures/external_tileset_room.lua + .tsx (new fixture map + external tileset, single-image shape)
- tests/integration/all_maps_load_test.lua or a new sibling integration test (extend to load the fixture map)
- res/map/sandbox.tmx, res/map/sandbox.lua (revert tileset reference to external; re-export or hand-edit to match)

## Test approach
Headless unit: given a literal `.tsx`-shaped XML string (mirroring `generic_platformer_tiles.tsx`'s actual content) and a `firstgid`, `external_tileset` returns a table with the same fields STI's own embedded-tileset parsing produces (`image`, `imagewidth`, `imageheight`, `tilewidth`, `tileheight`, `columns`, `spacing`, `margin`, `tilecount`). Error-path unit tests: missing file path raises, malformed XML raises. Integration: the fixture map (and `sandbox.lua` once reverted) loads through the real `Map`/STI stack without error, and a screenshot/manual check confirms the ground tiles render and collide as before.

## Acceptance criteria
- [ ] `external_tileset` resolves a single-image `.tsx` to a table shaped like STI's embedded-tileset output.
- [ ] `lib/sti/init.lua` no longer asserts on `tileset.filename`; it resolves and merges instead.
- [ ] A missing `.tsx` file or malformed tileset XML raises a clear error at load time.
- [ ] The fixture map (and `sandbox.lua`, reverted to an external tileset reference) loads through the real integration-tier stack without error.
- [ ] `./test-unit.sh` and `./test-integration.sh` pass.

## Blocked by
None — can start immediately.
