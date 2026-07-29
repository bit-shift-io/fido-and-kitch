# ADR 0004: Load Tiled `.tmx` directly, emitting the Lua exporter's table shape

**Status:** Accepted
**Date:** 2026-07-29

## Context

Maps are authored in Tiled as `.tmx` and loaded by the game from a `.lua` file that Tiled's Lua export plugin generates from them. That plugin has a silent defect: it does not resolve an object's class/type through an **object template**, so any object placed from a `res/templates/*.tx` file exports with `type = ""` instead of the type the template declares.

Entity construction selects a class purely from an object's `type` (`Map:loadEntity` walks `searchPaths` and `pcall(require, ...)` on the type name), so an emptied type makes the object silently become nothing. On two separate real re-exports of `sandbox.tmx` on the same day, this blanked the type on all eleven template-placed objects — including the spawn point, so the level loaded with **zero players** and no error, and the drawbridge, coin, cage, exit, switch, key, jump pad and push box became inert scenery.

The defect is narrow and was verified precisely: the exporter resolves `name`, `gid`, `width` and `height` through templates *correctly* — all eleven gid remappings in `sandbox.tmx` match the formula `templateGid − templateFirstgid + mapFirstgid` and the last known-good export. Only `type` is dropped. The exported file therefore looks complete and diffs innocuously, which is what made it cost real debugging time twice.

Beyond that one bug, the export step makes the exported `.lua` a committed derived artefact, so the repository can hold a map that disagrees with its own source: a Tiled edit saved but not re-exported changes nothing in game, and a re-export can independently drop a map's tileset list or bake in coordinates nudged off-grid during authoring. Both had already happened. The `.tmx` and `.tx` sources were correct in every case.

Immediately prior to this, external `.tsx` tileset support was added by vendoring an XML library and writing a resolver in `src/map/` that produces tileset tables shaped like the vendored loader's embedded-tileset output. That established the pattern, the dependency, and the loud-failure convention this decision builds on.

## Decision

**Parse `.tmx` (and the `.tx` templates it references) directly in project code, and emit exactly the table structure Tiled's Lua exporter emits.**

Two parts, both load-bearing:

**Abandon the exporter.** Map construction dispatches on file extension: `.tmx` is parsed to a table by `src/map/tmx.lua` and that table is handed to the vendored loader; `.lua` is loaded exactly as today. Because the parser resolves templates itself following Tiled's semantics — including remapping tile references into the map's numbering, and auto-registering a tileset a template references but the map does not declare — the dropped-type bug cannot recur, and there is no export step to forget.

**Mimic the exporter's output shape rather than designing a cleaner one.** The parser is a drop-in replacement for the export plugin, not a new internal representation. Consequently:

- No downstream code changes. Tile and object construction, layer drawing, sprite batching, collision building, tile animation and custom-property lookup all keep operating on the structure they already consume.
- The 18 hand-authored `.lua` fixture maps keep working untouched, because they are written in that same shape. They have no `.tmx` source and are maintained by hand precisely because no Tiled round-trip is wanted, so `.lua` support is permanent rather than transitional.
- **Tile layer data is emitted still base64-encoded**, alongside its encoding and compression markers, because the loader already decodes that form. This inherits base64, zlib and gzip handling for free instead of reimplementing it.
- Values Tiled omits from XML when they equal a default are materialised to the defaults the exporter writes — layer offsets, parallax factors, opacity, visibility, rotation, empty names and types, empty property tables — because downstream code reads them unconditionally.

**The vendored loader is not patched at all.** Its constructor already accepts a pre-built map table in place of a path, so dispatch lives entirely in project code. `patches/sti.patch` does not grow by a line. The condition this imposes — every emitted asset path resolved relative to the project root, tilesets marked as externally referenced — is already how the external-tileset resolver behaves.

Support is confined to what the project uses plus a small forward-looking set: base64 tile layers, object layers, grouped layers, image layers, rectangle/polyline/polygon/ellipse/point shapes, the standard scalar property types, templates, external tilesets, and maps declaring no tilesets. Anything else — CSV data, infinite or chunked maps, unrecognised layer types or shapes — raises an error naming the file and the construct.

## Alternatives Considered

**Repair the exported `.lua` after each export.** Rejected: relies on a human remembering a manual step after every Tiled edit, having already failed twice in one day, and leaves the derived-artefact divergence class untouched.

**Resolve templates only — keep loading the exported `.lua`, reading `.tmx`/`.tx` at load time purely to restore the dropped `type`.** Genuinely smaller, and the most serious alternative. Rejected because it still requires parsing `.tmx` XML to map object id → template path, so it pays most of the parsing setup cost while keeping the export step, the committed derived artefact, and the "did you re-export?" failure class. It fixes the instance, not the category.

**Design a clean internal map representation instead of mimicking the exporter.** Rejected: would require patching the vendored loader extensively — the thing the preceding work deliberately minimised — and would invalidate all 18 hand-authored `.lua` fixtures, since they are written in the exporter's shape. The cost is a parser that looks oddly half-finished at the tile-data step; the benefit is that nothing downstream changes and the fixtures survive.

**Patch the vendored loader to dispatch on extension internally.** Rejected: the loader is git-ignored and rebuilt by `setup.sh` from an upstream clone plus patches, so every patched line can conflict on an upstream update and lives outside normal review. Project code is version-controlled and unit-testable.

**Implement the whole Tiled format, or warn-and-continue on unsupported constructs.** Both rejected: the former is large unexercised surface; the latter would ship a level silently missing a layer, which is the exact failure mode this feature exists to eliminate.

**Report the defect upstream to Tiled and wait.** Not a substitute — an upstream fix would not arrive on this project's timeline, and would still leave the derived-artefact problem.

## Consequences

**Good.** Tiled edits take effect on save, with no export step and no derived artefact that can disagree with its source. The dropped-type bug is structurally impossible. A map that opens correctly in Tiled loads correctly in the game, including template tilesets the map never declared — a stronger guarantee than the exporter offered. Grouped layers, ellipse and point objects become available. The vendored loader's patch stays minimal, and one map format covers both levels and parallax background presets.

**Costs.** The project now owns Tiled format compatibility across future Tiled versions, where that burden previously sat with Tiled's own exporter — mitigated by only needing to track the subset actually used, and by differential tests pinned against preserved real exporter output. Emitting still-encoded tile data will read as unfinished to anyone unfamiliar with this reasoning, which is the main reason this ADR exists. Deleting the exported `.lua` files removes an at-a-glance readable view of each map, though that view was actively misleading. Two map formats coexist permanently. Converting the background presets widens the blast radius so that a parser defect could break every level's background, caught only by the rendered-screenshot tier. And a map using an unsupported construct hard-fails rather than degrading — deliberate, but it means an ellipse drawn in a future Tiled version's new shape type stops a level loading until the parser learns it.

**Reversibility.** Moderate. Re-adopting the exporter would mean re-exporting every map and restoring the deleted files — mechanical, but it would reintroduce the bug this decision exists to remove. Changing the *output shape* is the genuinely expensive half to reverse, since it would mean patching the vendored loader and rewriting all 18 hand-authored fixtures.
