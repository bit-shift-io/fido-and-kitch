# Handoff — Direct `.tmx` Map Loading

## Summary

Maps are authored in Tiled as `.tmx` but the game loads a `.lua` file that Tiled's export plugin generates. That plugin silently fails to resolve an object's class/type through an **object template**, so every object placed from a `res/templates/*.tx` file exports with `type = ""`. Entity construction picks a class purely from `object.type`, so those objects become nothing at all — on two real re-exports of `sandbox.tmx` on the same day this blanked all eleven template-placed objects, including the spawn point, so the level loaded with **zero players** and raised no error. The exporter gets `name`, `gid`, `width` and `height` right, so the broken export looks complete and diffs innocuously. Hand-repairing it after every Tiled edit is not a workable process.

The fix is to remove the exporter from the pipeline: parse `.tmx` (and the `.tx` templates it references) directly in project code, using the `xml2lua` library already vendored for external `.tsx` tilesets. The parser emits **exactly** the table shape Tiled's exporter emits, which is the load-bearing design choice — nothing downstream of loading changes, base64/zlib/gzip decoding is inherited for free, and the project's 18 hand-authored `.lua` fixture maps keep working untouched. `.lua` support stays permanently for those fixtures; the loader picks a path by file extension.

Full spec: [PRD.md](PRD.md). Rationale, measurements, and the verification of the template remapping rule: [DECISIONS.md](DECISIONS.md). The architectural decision — why the exporter was abandoned and why the parser deliberately mimics its odd output shape: [`docs/adr/0004-direct-tmx-loading.md`](../../docs/adr/0004-direct-tmx-loading.md). Glossary entries added for *Tiled map source* and *Object template*, and the existing *External tileset* entry corrected (it claimed templates already resolved correctly — the exact opposite of the truth).

Scope is 7 `.tmx` files: four levels under `res/map/` and three parallax background presets under `res/backgrounds/`. Six of them have `.lua` exports that get deleted at the end.

## Implementation order

1. **01-tmx-dispatch-and-tile-layers** — foundation: preserve the golden exports, create the parser, wire the extension dispatch, handle map attributes, properties, external tilesets and base64 tile layers, and establish the loud-failure behaviour. Everything else builds on this.
2. **02-object-layers-and-shapes** — object groups, object attributes and rectangle/polyline/polygon shapes. First real level (`ll1.tmx`) loads, and the differential test harness lands here because `ll1` is template-free and so must match its golden exactly.
3. **03-image-layers-and-backgrounds** — image layers, zero-tileset maps, and the second dispatch site. Independent of 02; could run in parallel with it.
4. **04-object-templates** — the payoff. `sandbox.tmx` loads with every type correct and players spawning. Needs 02's object parsing.
5. **05-group-layers-and-extra-shapes** — grouped layers and ellipse/point objects. Forward-looking, no real content uses them, so fixtures are the only specification.
6. **06-cutover-and-cleanup** — delete the six exports, resolve `tiny.tmx`, strip the export directives, teach enumeration about `.tmx`, update docs.

If you want the actual bug fixed as early as possible, 04 only depends on 01 and 02 — 03 and 05 can follow it.

## Implementer notes / gotchas

- **The parser's output shape is the contract, and it will look wrong.** Tile layer data is emitted *still base64-encoded* with its encoding/compression markers, because STI's `setLayer` already decodes exactly that. Resist the urge to decode it in the parser. Same principle everywhere: match what the exporter writes, not what seems cleanest. The golden diffs are the arbiter.

- **Default materialisation is the most likely source of subtle bugs.** Tiled omits attributes equal to their defaults; the exporter writes them explicitly; downstream code reads them unconditionally. `offsetx`/`offsety` `= 0`, `parallaxx`/`parallaxy` `= 1`, `opacity = 1`, `visible = true`, `class = ""`, empty `name`/`type` as `""` not nil, `properties = {}`. This is precisely what the exact-match golden diff on `ll1` and the three backgrounds exists to pin.

- **`external_tileset.resolve` does not return the tileset's `name`, and the parser needs it.** In a `.lua` export the name sits on the map's tileset entry, but a `.tmx`'s `<tileset source="...">` has no name attribute — it lives inside the `.tsx`. STI uses `tileset.name` as the image-collection atlas cache key. Add `name` to the resolver's return value in issue 01.

- **Every emitted path must be project-root-relative.** This is the condition that lets us patch STI zero further. STI's constructor accepts a pre-built table, but then its internal directory argument is empty, so `format_path(path .. tileset.filename)`, `format_path(path .. layer.image)` and the tile-image paths all resolve only if the parser has already normalised them against each source file's own directory. `external_tileset` already does this for images; do the same for tileset `filename` and image-layer `image`. Reuse `lib/sti/utils.lua`'s `format_path`.

- **Do not add a single line to `patches/sti.patch`.** `lib/` is git-ignored and rebuilt by `setup.sh` from an upstream clone plus patches, so patched lines can conflict on upstream updates and sit outside normal review. All new code goes in `src/map/`. There are exactly two `sti()` call sites, both in `src/map.lua` — levels and background presets.

- **Cache templates, never parsed maps.** STI mutates the map table in place: it replaces `layer.data` twice, attaches instance-capturing closures, sets a metatable, injects layer-name keys, and — the killer — accumulates `layer.x = (layer.x or 0) + layer.offsetx + self.offsetx`, which would double-offset every layer on a second load. Grouped layer names would compound too. Measured parse cost for the largest map is 2.37 ms, so there is nothing to gain. Templates are safe to cache because resolution only reads them.

- **Real fixtures beat invented ones.** Build test XML from the structure of the actual files — `res/map/ll1.tmx`, `res/backgrounds/night_forest.tmx`, `res/templates/*.tx`, `res/tilesets/props.tsx`. This already caught a requirement during the preceding external-tileset work that synthetic XML would have missed. Real maps contain fractional coordinates, large negative offsets, and a parallax factor of `0` that must not be defaulted to `1`.

- **The template remapping rule is verified, not guessed.** `DECISIONS.md` Q5 lists the expected result for all twelve templates (`spawn.tx` gid 1 → 145 through `drawbridge.tx` gid 12 → 156), checked against the last known-good export. Use it as a checklist. If your golden diff needs to allowlist anything other than `type`, the parser is wrong.

- **Image layers are live production content, not a dormant path.** They were nearly planned as an unsupported construct. The parallax background system loads `res/backgrounds/*.lua` as Tiled maps consisting entirely of image layers, so rejecting them would have broken every level's background. Two different consumers read those layers with different field expectations: STI's `drawImageLayer`, and the project's own background loop in `src/map.lua`.

- **Only the screenshot tier can see a background or a missing player.** The headless tiers never draw. The original bug loaded a level with no error and no player. Treat `./test-e2e.sh` as required for issues 03, 04 and 06, and actually look at the captures.

- **Watch for false passes in map enumeration.** The all-maps load and screenshot tests discover maps by shelling out for `res/map/*.lua`. A glob that returns zero files still passes every per-map assertion. Issue 06 requires asserting the discovered count explicitly.

- **`tiny.tmx` is broken.** It references `../generic_platformer_tiles.tsx`, resolving to a path that does not exist (the tileset is one directory deeper), and it is Tiled 1.5.0 vintage against 1.12.2 everywhere else. It has never been loadable because enumeration only found `.lua` files. Once `.tmx` is enumerated it will hard-error. Do not use it as a fixture in issue 01; ask the user in issue 06 whether to repoint or delete it.

- **There is one pre-existing unit-test failure** — a camera-convergence assertion — that fails identically on an unmodified tree. Leave it alone; just confirm it stays the only failure.

- **Testability seam pattern:** mirror `src/map/external_tileset.lua` — pure table-shaping logic with an injectable file reader, so most of the parser is testable headless against literal XML strings. Prior art for the tests themselves: `tests/unit/external_tileset_test.lua` and `tests/integration/all_maps_load_test.lua`.

- **Test runner scripts** are `./test-unit.sh`, `./test-integration.sh`, `./test-e2e.sh` and `./test-all.sh`. New test files must be registered in their tier's manifest in the corresponding `run.lua`, or they silently never run.
