# Decisions — External Tileset Support for STI

Grill session 2026-07-29, prompted by `sandbox.lua` failing to load ("STI does not support external Tilesets") after a fresh Tiled export dropped the previously-embedded `generic_platformer_tiles` tileset.

### Q1: Which library should load Tiled maps?
**Decision:** Keep the vendored `lib/sti/` (Simple Tiled Implementation) and patch it locally to resolve external tilesets, rather than migrating to another library.
- **Why:** Researched the realistic alternatives first:
  - **Cartographer** (tesselode) — the most commonly cited modern STI alternative for LÖVE. Read its source directly: same fundamental gap (only handles fully-embedded tileset data, no `filename`/`source` resolution). Checked its commit history: last commit October 2020 — more dormant than STI, not less.
  - **Advanced Tiled Loader** — does support external tilesets and raw `.tmx`, but has been unmaintained even longer, and its own documentation recommends switching to STI instead.
  - **STI itself** — last tagged version is 2019, but its actual GitHub commit history has a merged PR as recent as March 2024 (a parallax feature). More recently touched than Cartographer, despite the stale version number giving the opposite impression.
  - No actively-maintained Lua library for LÖVE (or otherwise) that loads raw `.tmx` directly was found.
- **Implication:** The real fix is a small, scoped patch to code we already vendor and understand, not a migration. Migrating to Cartographer would have meant touching every place this codebase reads STI's map/layer/tileset shape, for a library objectively more dormant than the one already in use.
- **Alternatives considered:** Migrate to Cartographer (rejected — more dormant, same gap); migrate to Advanced Tiled Loader (rejected — unmaintained, self-deprecated); build a from-scratch raw-`.tmx` loader (rejected as disproportionate effort/risk for what's needed — see Q2).

### Q2: Load raw `.tmx` directly, or keep the Tiled `.lua` export step?
**Decision:** Keep exporting to `.lua` via Tiled; only the *referenced external `.tsx`* is parsed as XML.
- **Why:** User's stated preference was "ideally... but at least a lua file" — the `.lua` export path already works well for everything except external tilesets. Replacing the export step entirely would be a much larger, separately-risky effort for no benefit beyond what patching the one gap already provides.
- **Implication:** Maps are still authored/exported the same way as today; only `.tsx` (a much smaller, simpler XML grammar than full `.tmx`) needs parsing.

### Q3: Which tileset shapes to support?
**Decision:** Both — a single shared-image grid tileset (`generic_platformer_tiles.tsx`, `columns > 0`) and an image-collection tileset with one `<image>` per `<tile>` (`props.tsx`, `columns = 0`).
- **Why:** `props.tsx` already exists on disk as a real image-collection tileset (backing the deferred Background prop feature and Tiled's own object-template previews), and its tiles include cropped sub-regions of larger source images (e.g. `switch.png` is 488×162 but tile id 3 crops a 162×162 region from it) — confirmed by reading the actual file. Supporting only the grid shape would leave `props.tsx` broken the moment it's referenced externally.
- **Implication:** The resolver must handle per-tile image + optional crop rect (`x`/`y`/`width`/`height` distinct from the source image's own dimensions), not just a single shared image sliced on a fixed grid.

### Q4: How to parse the `.tsx` XML?
**Decision:** Vendor a general-purpose XML library (`xml2lua`) rather than hand-roll a parser scoped to today's known tags.
- **Why:** A hand-rolled parser would need extending every time a real `.tsx` uses a tag we didn't anticipate (this already happened once during the grill — `props.tsx` turned out to need cropped sub-image support that wasn't obvious up front). `xml2lua` (MIT, pure Lua 5.1+, no C bindings) has a built-in DOM-style tree handler that converts XML straight into nested Lua tables, keeping the resolver's own code to table lookups rather than parser maintenance.
- **Alternatives considered:** SLAXML (SAX-style streaming, would require hand-writing state-machine callbacks to rebuild a tree — rejected as more glue code for no benefit here); hand-rolled scoped parser (rejected per above).

### Q5: Should per-tile properties/animation/collision shapes resolve too, or just image/geometry?
**Decision:** Resolve all of it — `<properties>`, `<animation>`, and the Tile Collision Editor's per-tile `<objectgroup>` — in the same shape STI already builds for embedded tiles.
- **Why:** Confirmed by reading `lib/sti/init.lua` that STI genuinely consumes `tile.properties` (exposed via `Map:getTileProperties`) and `tile.animation` (drives real animated-tile rendering) for embedded tilesets today — these aren't speculative, they're existing STI features that an external tileset would otherwise lack relative to an embedded one.
- **Implication (objectGroup specifically):** `tile.objectGroup` is also carried through by STI, but this project's own collision model is built entirely from map-level object layers (`collision`/`kill`/`ladder` objectgroups) and does not read tile-level collision shapes at all today. Resolving it keeps external and embedded tilesets at parity and costs the same shape of work as properties/animation, but it's parsed for parity only — flagged explicitly so nobody mistakes it for a new collision feature.
- **Alternatives considered:** Geometry/image only, deferring properties/animation/objectGroup until something needs them — rejected once it was confirmed properties/animation are already active STI features being lost, not hypothetical future ones.

### Q6: Caching
**Decision:** Cache resolved tilesets by `.tsx` file path, for the process lifetime.
- **Why:** Avoids re-parsing the same external tileset's XML on every map load (level restarts, revisiting a level, multiple maps sharing a tileset). `.tsx` files don't change mid-session, so no invalidation is needed.

### Q7: Error handling for a broken external tileset reference
**Decision:** Fail loudly (hard error) at map-load time for a missing `.tsx`, malformed tileset XML, or a `.tsx` referencing a missing image — not a warn-and-skip.
- **Why:** Considered the existing "unknown entity type" convention in `Map:loadEntity`, which warns and continues rather than crashing. But a broken tileset means every tile layer depending on it is unrenderable/uncollidable — the map is effectively broken either way, so surfacing the problem immediately at load is more useful than shipping a level with silently invisible tiles. This also matches STI's own existing convention of asserting on tileset invariants (the very assertion this feature replaces was itself a hard failure).
- **Alternatives considered:** Warn-and-skip like unknown entity types — rejected, severity doesn't match (one missing decorative entity vs. an entire unrenderable tile layer).

### Q8: Tiled export workflow going forward
**Decision:** `sandbox.tmx` reverts to referencing its tileset externally; the "Embed tilesets" Preferences → Export Options setting is no longer required for this project once this feature ships.
- **Why:** External-reference is Tiled's own default/recommended workflow since 1.0. Requiring "Embed tilesets" was a workaround for STI's limitation, not a real project preference.
- **Implication:** Embedded tilesets still work fine if a future export happens to embed them (nothing breaks either way) — this just removes the requirement, it doesn't forbid embedding.

## Assumptions

- `xml2lua`'s DOM-style tree handler is sufficient for `.tsx`'s XML grammar (elements, attributes, nesting) without needing SAX-level control — assumed based on reading its README/example, not yet proven against our actual fixture files (first thing the implementation issues verify).
- No other `.tsx` shape (e.g. Wang sets, terrain definitions) is in use anywhere in this repo today; only grid and image-collection shapes, confirmed by reading every `.tsx` currently on disk.

## Trade-offs

- Vendoring a second small XML dependency (`xml2lua`) alongside an already-vendored, semi-dormant map library (STI) adds a bit more third-party surface area — accepted because the alternative (hand-rolled parser) would need repeated extension as real `.tsx` content keeps surfacing tags we didn't anticipate (as already happened once with `props.tsx`'s cropped sub-images).
- Resolving per-tile `objectGroup` data that nothing in this codebase currently consumes is a small amount of otherwise-unused plumbing — accepted for parity with embedded tilesets and because the parsing cost is shared with properties/animation, not separate work.

## CONTEXT.md entries added

External tileset (see `CONTEXT.md` for definition).
