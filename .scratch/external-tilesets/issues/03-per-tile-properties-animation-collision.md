Status: done

# Resolve per-tile properties, animation, and collision-editor shapes

## What to build
Per-tile `<properties>`, `<animation>`, and the Tile Collision Editor's per-tile `<objectgroup>`, when present in an external `.tsx` (either shape), resolve into the same fields STI already gives embedded tiles: `tile.properties` (readable via `Map:getTileProperties`), `tile.animation` (drives STI's existing animated-tile rendering), and `tile.objectGroup` (carried through for parity; not consumed by this project's own collision system, which continues to come from map-level object layers — see PRD "Out of Scope").

## Files to create/modify
- src/map/external_tileset.lua (extend: per-tile `<properties>`, `<animation>`, `<objectgroup>` parsing)
- tests/unit/external_tileset_test.lua (extend)
- tests/fixtures/ — a fixture `.tsx` with at least one tile carrying custom properties and one with an animation sequence (a real embedded example already exists somewhere in a shipped map/tileset to model the expected shape against — check `res/tilesets/` and any embedded tilesets in `res/map/*.lua` for an animated or property-bearing tile to mirror)

## Test approach
Headless unit: given literal XML with a `<tile>` carrying `<properties>`, assert the resolved table's `properties` matches. Same for a `<tile>` with an `<animation>` sequence (multiple `<frame tileid="..." duration="..."/>` entries) and a `<tile>` with an `<objectgroup>` (one or more collision shapes). Integration: a fixture map using an animated external tile advances frames the same way an embedded animated tile does (reuse or mirror however the existing STI animation update path is already exercised, if at all, or add a minimal integration check driving a few frames and asserting the tile's current frame advances).

## Acceptance criteria
- [ ] Per-tile custom properties on an external tileset are readable via `Map:getTileProperties`, matching embedded-tileset behaviour.
- [ ] Per-tile animation frames on an external tileset animate the same way embedded-tileset animated tiles do.
- [ ] Per-tile `objectGroup` data on an external tileset is parsed and present in the same shape STI gives embedded tiles.
- [ ] `./test-unit.sh` and `./test-integration.sh` pass.

## Blocked by
01
