Status: done

# Cache resolved external tilesets by file path

## What to build
A second reference to the same external `.tsx` path (a second map using the same tileset, or the same map loaded twice — e.g. a level restart) reuses the previously-resolved tileset table instead of re-parsing the XML. The cache lives for the process lifetime; `.tsx` files never change mid-session, so no invalidation is needed.

## Files to create/modify
- src/map/external_tileset.lua (add a path-keyed cache around the resolution entry point, covering both tileset shapes from issues 01/02 and the per-tile metadata from issue 03)
- tests/unit/external_tileset_test.lua (extend)

## Test approach
Headless unit: resolve the same `.tsx` path twice, assert the underlying parse/file-read only happened once (inject a counting spy or track calls via a seam the module already exposes for testing — e.g. an injectable file-reader/parser dependency, mirroring how other pure modules in this codebase take dependencies rather than reaching for globals). Assert the second call still returns a correct, fully-shaped tileset table (not just "didn't crash").

## Acceptance criteria
- [ ] Resolving the same `.tsx` path twice parses its XML only once.
- [ ] The cached result is identical in shape/content to a fresh resolution.
- [ ] Two different `.tsx` paths are cached independently (resolving one doesn't serve the other's data).
- [ ] `./test-unit.sh` passes.

## Blocked by
01
