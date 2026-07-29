# Direct `.tmx` Map Loading

## Problem Statement

Maps are authored in Tiled as `.tmx` files but the game loads a `.lua` file that Tiled exports from them. That export step is unreliable, and the unreliability is silent.

Tiled's Lua exporter does not resolve an object's **class/type** through an object template. Any object placed from a template — which is how nearly every interactive prop in this project is placed — exports with `type = ""` instead of the type declared in the template file. The exporter gets everything else about the template right (name, gid, width, height all resolve correctly), so the exported file looks complete and diffs innocuously. But the game selects which entity class to spawn purely from an object's `type`, so an emptied `type` means the object silently becomes nothing at all.

The consequences observed on real re-exports: a map where the spawn point's type was blanked spawned **zero players**, so the level loaded to an empty screen with no error. In the same map the drawbridge, coin, cage, exit, switch, key, jump pad and push box all became inert scenery. This happened on two separate exports on the same day, and hand-repairing the exported file after each Tiled edit is not a workflow anyone can be expected to remember.

The export step causes a second class of problem beyond the type bug: the exported `.lua` is a committed derived artefact, so the repository can hold a map that disagrees with its own source. A Tiled edit that is saved but not re-exported changes nothing in the game; a re-export can also quietly drop or change a map's tileset list, or bake in coordinates that were nudged off-grid during authoring. Every one of these has already cost debugging time. The `.tmx` and `.tx` source files, meanwhile, are correct in every case — only the exporter is wrong.

## Solution

The game loads `.tmx` files directly. A new map parser reads the Tiled XML — and the `.tx` template files it references — and produces the map data structure the loader already consumes, so the exporter is removed from the pipeline entirely rather than worked around.

Because the parser resolves object templates itself, following Tiled's own inheritance rules, the dropped-type bug cannot recur. Because there is no longer a derived artefact, a map cannot disagree with its source and there is no export step to forget. Authoring becomes: edit in Tiled, save, run the game.

The parser's output is deliberately shaped **exactly** like Tiled's Lua export. This is the load-bearing design choice: it means no downstream code changes — tile and object construction, layer drawing, sprite batching, collision building, tile animation and custom-property lookup all continue to operate on the structure they already expect. It also means the project's hand-authored `.lua` fixture maps keep working untouched, since they are written in that same shape. The loader picks a path by file extension, so the two formats coexist permanently: `.tmx` for anything authored in Tiled, `.lua` for fixtures hand-written for tests where no Tiled round-trip is wanted.

Loading is confined to what this project actually uses, plus a small set of constructs the team expects to reach for soon. Anything outside that set fails loudly at load time, naming the offending file and the specific construct, rather than loading a partial map.

## User Stories

1. As a level designer, I want to edit a map in Tiled and see the change in the game after saving, so that I never have to remember a separate export step.
2. As a level designer, I want an object placed from a template to keep the type declared in that template, so that props I place actually function instead of becoming invisible scenery.
3. As a level designer, I want a template's tileset to work even when the map itself does not declare that tileset, so that dragging a template from Tiled's palette into a fresh map just works, exactly as it does inside Tiled.
4. As a level designer, I want my parallax background presets authored in Tiled to load the same way levels do, so that there is one map format and one workflow across the whole project.
5. As a level designer, I want a map that uses a construct the loader does not support to fail immediately with a message naming the file and the construct, so that I find out while I am authoring rather than after shipping a broken level.
6. As a level designer, I want to organise a growing map into groups of layers in Tiled, so that a complex level stays navigable.
7. As a level designer, I want to draw ellipse and point objects in Tiled, so that I am not restricted to rectangles when marking up a map.
8. As a developer, I want tile layer data, object layers, image layers, object shapes and typed custom properties to arrive in exactly the structure the loader already consumes, so that adopting direct loading changes no rendering, collision or gameplay code.
9. As a developer, I want hand-authored `.lua` fixture maps to keep loading unchanged, so that the existing test suite is unaffected by this change.
10. As a developer, I want the parser's output verified field-by-field against real Tiled exporter output, so that I can trust it reproduces the structure faithfully rather than approximately.
11. As a developer, I want the parser to live in project source rather than in the vendored map library, so that it is version-controlled, testable, and does not enlarge the patch applied to that library on every setup.
12. As a developer, I want a map with no tilesets at all to load, so that image-layer-only background presets work.
13. As a developer, I want repeated template files parsed once per run, so that a map referencing a dozen templates does not re-read and re-parse the same files.
14. As a developer, I want a missing, malformed or unreadable `.tmx`, `.tx` or `.tsx` to raise a clear error naming the file, so that a typo in a path is obvious immediately.
15. As a player, I want levels and their parallax backgrounds to look and behave exactly as they did before this change, so that the migration is invisible to me.

## Implementation Decisions

### Parser output is the integration contract

The parser emits the same table structure Tiled's Lua exporter emits. Every consumer downstream of the loader is unchanged. Two consequences worth stating explicitly:

- Tile layer data is emitted **still encoded** — the base64 string, alongside its encoding and compression markers — because the loader already decodes that form. This inherits base64, zlib and gzip handling for free rather than reimplementing it, and is why the parser looks like it is doing less work than expected at that step.
- Values Tiled omits from XML when they equal a default must be materialised to the defaults the exporter writes, because downstream code reads them unconditionally. Layer offsets, parallax factors, opacity, visibility, rotation, empty names, empty types and empty property tables all fall into this category.

### Dispatch by file extension in project code

Map construction routes on the file extension: `.tmx` is parsed to a table and that table is handed to the loader; `.lua` continues to be loaded exactly as it is today. Both of the project's map-construction sites route this way, so levels and background presets behave identically.

This requires **no change to the vendored library**, because the library already accepts a pre-built map table in place of a path. The condition attached to that route is that all asset paths in the emitted table must be resolved relative to the project root and tilesets must be marked as externally referenced — which is already how the existing external-tileset resolver emits paths.

### Object template resolution

Templates are resolved following Tiled's own semantics:

- An instance inherits every attribute from its template object, and any attribute present on the instance overrides the inherited one.
- Custom properties merge, with the instance's value winning on a name collision.
- A template's tile reference is expressed in that template's own tileset numbering and must be remapped into the map's numbering. This remapping was verified against all eleven template instances in the largest real map; every one resolves to the value Tiled's exporter produces, confirming that the exporter's only defect here is the dropped type.
- Both the modern and legacy spellings of the class/type attribute are accepted on objects and templates, since Tiled's rename of that concept is the most plausible origin of the exporter defect and a future version may write either.

If a template references a tileset the map does not declare, the parser loads that tileset and appends it to the map's tileset list, allocating its tile-numbering offset deterministically after the existing tilesets. This matches Tiled's behaviour, so any map that opens correctly in Tiled loads correctly in the game.

Parsed templates are cached by path for the process lifetime. Template data is only ever read during resolution — merging builds fresh object tables — so nothing aliases.

### Parsed maps are deliberately not cached

The loader mutates the map table in place and extensively: it attaches a metatable, replaces tile layer data twice (encoded string, then decoded identifier list, then a grid of live tile references), accumulates layer offsets additively, attaches draw and update closures that capture the specific map instance, rewrites grouped layer names, injects layer-name keys into the layer list, computes object vertex data, and attaches entity references. Reusing a cached table would require a deep copy on every retrieval — more expensive than simply re-parsing, and a source of cross-load aliasing bugs. Parsing the largest map measures well under a single frame, against a level load that is dominated by image decoding and collider construction, so there is nothing to gain.

### Supported constructs

Tile layers with base64 data; object layers; grouped layers; image layers including their repeat, parallax and offset attributes; rectangle, polyline, polygon, ellipse and point object shapes; the standard scalar custom-property types; object templates; externally referenced tilesets; and maps declaring no tilesets at all.

Polygon support is included despite being unused because it shares the polyline parser and the loader already handles it downstream, so excluding it would cost more code than including it.

### Unsupported constructs fail loudly

CSV-encoded tile layer data, infinite and chunked maps, and any unrecognised layer type, object shape or property type raise an error naming the map file and the specific construct. CSV is explicitly rejected rather than supported: the tile layer format is a Tiled project preference, so if it is ever flipped the failure should be immediate and legible across every map at once rather than silently divergent.

### Existing tileset cache hardening

The external-tileset resolver hands out a shallow copy of its cached entry, so nested per-tile tables are shared by reference between the cache and every map that uses the tileset — and those references reach code that reads tile custom properties. Nothing mutates them today, making this latent rather than live, but this work reasons directly about caching and copy semantics and is the right moment to close it.

### Migration and cutover

The six exported `.lua` files that have a `.tmx` source are deleted; the `.tmx` files become the sole source of truth. The Tiled export directive embedded in each map file is removed. Level enumeration — both the in-game level select and the test helpers that discover maps — recognises `.tmx` alongside `.lua`, so hand-authored fixtures continue to be found.

One map requires a decision at implementation time: the project contains a small, stale scratch map, authored against a much older Tiled version, whose tileset reference points at a path that does not exist. It is currently unloadable and unreachable, because enumeration only finds exported `.lua` files and it has none. Once enumeration includes `.tmx` it becomes reachable and, under the fail-loudly rule, will error. It should either be repointed at the correct tileset path or deleted; it must not be left to break map enumeration.

## Testing Decisions

Two complementary layers, because neither alone is sufficient.

**Differential tests against real exporter output.** Six maps currently exist as both a `.tmx` source and a Tiled-exported `.lua`. Those exports are preserved as golden fixtures before being deleted from the content directories, and the parser's output is compared against them field by field. For maps with no template instances the match is exact, which pins every default-materialisation detail — the class of thing that is easy to get subtly wrong and invisible in play. For maps with template instances the match is exact except for the enumerated set of types the exporter dropped, where the parser is asserted to produce the correct value and the export the empty one; this both verifies the fix and documents the bug precisely. These goldens are genuine Tiled output, not fixtures invented to match the implementation, which is what makes them worth having.

**Per-construct unit tests against literal XML.** Each construct gets focused tests built from literal XML strings: template inheritance and attribute override, property merging, tile-numbering remapping, tileset auto-registration, each property type's coercion, each object shape, grouped layers, image layer attributes, default materialisation, and every loud-failure path. This is what makes a failure point at a specific construct rather than at "the whole map differs", and it is the only way to cover the error paths and the rejected constructs, which by definition have no golden.

Both tiers run headless. Fixture XML mirrors the structure of the project's real map and template files rather than a simplified form, so that quirks present in real Tiled output are exercised. The existing whole-project checks — every map loads and steps frames, and the rendered-screenshot tier — provide the end-to-end backstop, and the screenshot tier is the only place that can confirm parallax backgrounds still render correctly.

Prior art to mirror: the external-tileset resolver's unit tests for the pure-parsing-with-injected-file-reader pattern, and the all-maps load test for the real-content-through-the-real-stack pattern.

File naming and location follow the project's Lua conventions: unit tests under the unit test directory, integration tests under the integration directory, both registered in their tier's runner manifest, run via the existing tier scripts.

## Out of Scope

- Supporting CSV tile layer data, infinite or chunked maps, or any layer type, object shape or property type not listed as supported. These raise errors; adding them later is a contained change.
- Converting the hand-authored `.lua` fixture maps to `.tmx`. They exist precisely because they are maintained by hand without a Tiled round-trip, and the `.lua` path remains permanently supported for them.
- Writing `.tmx` files. The parser is read-only; Tiled remains the only authoring tool.
- Changing the map data structure, the rendering pipeline, the collision model, or any entity behaviour. The parser's entire purpose is to produce the existing structure.
- Enlarging the patch applied to the vendored map library. This feature adds none.
- Reporting the exporter defect upstream to Tiled, or attempting to fix Tiled's Lua export plugin.
- Contributing direct `.tmx` loading upstream to the vendored map library.
- Replacing or re-evaluating the vendored map library itself.

## File Structure

```
src/
  map.lua                        -- extension dispatch at both map-construction sites
  map/
    tmx.lua                      -- new: .tmx path -> exporter-shaped map table
    tmx_template.lua             -- new: .tx resolution, inheritance, gid remap, cache
    external_tileset.lua         -- existing; shallow-copy hardening
res/
  map/
    sandbox.tmx  ll1.tmx  ll2.tmx  tiny.tmx
    (sandbox.lua, ll1.lua, ll2.lua deleted)
    drawbridge_fixture.lua       -- hand-authored, stays .lua
  backgrounds/
    night_forest.tmx  mushroom_cave.tmx  sky.tmx
    (their .lua exports deleted)
tests/
  unit/
    tmx_test.lua                 -- new
    tmx_template_test.lua        -- new
  integration/
    tmx_golden_test.lua          -- new: differential vs preserved exports
  fixtures/
    tmx/                         -- new: purpose-built .tmx/.tx construct fixtures
    golden/                      -- new: preserved Tiled exports for differential tests
```

## Acceptance Criteria

- [ ] A map authored in Tiled loads directly from its `.tmx` with no export step.
- [ ] An object placed from a template resolves the type declared in that template; the map that previously spawned zero players spawns its players, and its drawbridge, coin, cage, exit, switch, key, jump pad and push box all function.
- [ ] A template's tile reference remaps correctly into the map's tile numbering, matching the values Tiled's exporter produces.
- [ ] A template referencing a tileset the map does not declare loads, with that tileset auto-registered.
- [ ] Instance attributes override template attributes, and custom properties merge with the instance winning.
- [ ] Tile layers, object layers, grouped layers and image layers all load; image layer repeat, parallax and offset behave as before.
- [ ] Rectangle, polyline, polygon, ellipse and point object shapes load.
- [ ] Every supported custom-property type coerces to the value the exporter produces, and values omitted from XML materialise to the exporter's defaults.
- [ ] A map with no tilesets loads.
- [ ] All three parallax background presets load from `.tmx` and render identically to before.
- [ ] CSV data, an infinite map, an unrecognised construct, and a missing or malformed `.tmx`/`.tx`/`.tsx` each raise an error naming the file and the construct.
- [ ] A repeated template file is parsed once per process run.
- [ ] Parser output matches the preserved Tiled exports field-for-field, exactly for template-free maps and modulo the enumerated dropped-type delta for the rest.
- [ ] Hand-authored `.lua` fixture maps load unchanged.
- [ ] The six redundant `.lua` exports are deleted and the stale scratch map is either repointed or removed.
- [ ] Level enumeration finds `.tmx` and `.lua` maps, in the game and in the test helpers.
- [ ] The vendored library's patch is unchanged in size.
- [ ] Unit, integration and end-to-end tiers all pass, including the rendered-screenshot check for backgrounds.

## References

- `CONTEXT.md` — glossary entries for Tiled map source, Object template, and a correction to the existing External tileset entry.
- `docs/adr/0004-direct-tmx-loading.md` — why the exporter was abandoned and why the parser mimics its output shape.
- `.scratch/tmx-direct-loading/DECISIONS.md` — grill Q&A, measurements, and verification of the template remapping rule.
- The external-tileset work that preceded this, which vendored the XML library and established the resolver and loud-failure patterns this feature extends.
