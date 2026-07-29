Status: done

# Resolve object templates — the bug this feature exists to fix

## What to build

`res/map/sandbox.tmx` loads directly from its `.tmx` with every template-placed object carrying the type its template declares. Concretely: **players spawn**, and the drawbridge, coin, cage, exit, switch, key, jump pad and push box all function as entities rather than being silently dropped. This is the payoff slice — after it, the defect that motivated the whole feature is structurally impossible.

Scope for this slice:

- **Template parsing** — read a `.tx` file, extract its single object and its optional tileset reference.
- **Inheritance** — an instance inherits every attribute from its template object; any attribute present on the instance overrides the inherited one. Custom properties merge, with the instance's value winning on a name collision. The merge must build a **fresh** object table rather than mutating the cached template.
- **Tile reference remapping** — a template's `gid` is expressed in that template's own tileset numbering and must be remapped as `templateGid − templateFirstgid + mapFirstgidForThatTileset`. `DECISIONS.md` Q5 lists the verified expected result for all twelve templates; use it as a checklist.
- **Tileset auto-registration** — if a template references a tileset the map does not declare, load it and append it to the map's tileset list, allocating its `firstgid` deterministically after the existing tilesets. This matches Tiled, so any map that opens correctly in Tiled loads correctly here.
- **Template cache** — parsed templates cached by path for the process lifetime. `sandbox.tmx` has eleven instances across ten distinct files (`teleport.tx` twice), and the same templates recur across maps.
- **Existing tileset cache hardening** — `external_tileset.resolve` returns a shallow copy, so nested per-tile tables are shared by reference between the cache and every map using that tileset, and those references reach `Map:getTileProperties`. Latent today, but this slice is where copy semantics are being reasoned about. Close it.
- **Loud failures** — a missing or malformed `.tx`, and a template whose tileset cannot be resolved.

`ll2.tmx` (one template instance) converts in this slice too.

## Files to create/modify

- `src/map/tmx_template.lua` (new — `.tx` parsing, inheritance, remapping, cache)
- `src/map/tmx.lua` (extend: resolve `template` attributes on objects, auto-register template tilesets)
- `src/map/external_tileset.lua` (deep-copy the nested per-tile tables on retrieval)
- `tests/unit/tmx_template_test.lua` (new) and register it in `tests/unit/run.lua`
- `tests/unit/external_tileset_test.lua` (extend: assert cache entries do not alias)
- `tests/integration/tmx_golden_test.lua` (extend: `ll2` and `sandbox` with the dropped-type allowlist)
- `tests/integration/tmx_test.lua` (extend: sandbox entity spawning)

## Test approach

**Unit (headless, literal XML, injected reader).** Inheritance: an instance with no `name`/`type`/`width`/`height` inherits all four; an instance overriding `name` keeps its own and inherits the rest. Property merge: template-only, instance-only, and colliding names where the instance wins. Remapping: a template gid against a map firstgid other than the template's, asserting the arithmetic — use the twelve verified values from `DECISIONS.md` Q5. Auto-registration: a template referencing an undeclared tileset appends it with a deterministic `firstgid`; a template referencing an already-declared tileset does **not** duplicate it. Cache: the same `.tx` resolved twice reads the file once, and mutating a resolved object does not affect a subsequently resolved instance of the same template (the anti-aliasing check). Loud failures: missing `.tx`, malformed `.tx`, unresolvable template tileset.

For the tileset cache hardening, add a test asserting that mutating a resolved tileset's per-tile properties does not leak into a second resolution of the same path.

**Integration.** Two differential checks, both using the harness's expected-difference allowlist:

- `ll2.tmx` against its golden, with its one template instance's `type` allowlisted.
- `sandbox.tmx` against its golden, with the eleven template instances' `type` allowlisted.

In both cases the assertion is directional and specific: the parser produces the **correct** type and the golden export holds the **empty** one. That both verifies the fix and documents the exporter's defect precisely. Every other field must match exactly.

Then the behavioural test that actually matters: `sandbox.tmx` loads through the real stack and **spawns its players** (the original symptom was zero players), and each expected entity type is present — drawbridge, coin, cage, exit, switch, key, jump pad, push box.

**End-to-end.** Capture a rendered frame of `sandbox.tmx` and confirm players and props are visible. The original bug produced a level that loaded without error and drew no player at all, which only a rendered frame reveals.

## Acceptance criteria

- [ ] `res/map/sandbox.tmx` loads directly and spawns its players.
- [ ] All eight template-placed prop types in `sandbox.tmx` resolve to their template's declared type and function as entities.
- [ ] `res/map/ll2.tmx` loads directly with its template instance resolved.
- [ ] Instance attributes override template attributes; properties merge with the instance winning.
- [ ] All twelve template gid remappings match the verified values in `DECISIONS.md` Q5.
- [ ] A template referencing an undeclared tileset auto-registers it with a deterministic `firstgid`; an already-declared tileset is not duplicated.
- [ ] A repeated `.tx` is read and parsed once per process run.
- [ ] Resolving a template twice yields independent object tables — no aliasing.
- [ ] `external_tileset`'s cache no longer shares nested per-tile tables with its callers.
- [ ] A missing or malformed `.tx`, or an unresolvable template tileset, raises an error naming the file.
- [ ] Differential checks for `ll2` and `sandbox` match their goldens except the allowlisted `type` fields, where the parser is correct and the export empty.
- [ ] A rendered frame of `sandbox.tmx` shows players and props.
- [ ] `./test-unit.sh`, `./test-integration.sh` and `./test-e2e.sh` pass.

## Implementer notes

- **The exporter's only defect is `type`.** It resolves `name`, `gid`, `width` and `height` through templates correctly — verified against all eleven `sandbox.tmx` instances. So the golden diff's allowlist should be *exactly* the `type` fields; if you find yourself allowlisting anything else, the parser is wrong, not the exporter.
- **Templates carry their own tileset with `firstgid="1"`.** Every `.tx` in this project declares `<tileset firstgid="1" source="../tilesets/props.tsx"/>`, so the remap reduces to `templateGid - 1 + mapFirstgid` for all of them. Do not hard-code that — read the template's `firstgid`.
- **Tileset identity is the resolved source path, not the name.** Deciding whether a template's tileset is already declared must compare normalised paths; two maps can name the same `.tsx` differently, and the `.tmx` tileset reference has no name at all.
- `sandbox.tmx`'s props tileset *is* declared (added during the preceding external-tileset work), so auto-registration will not be exercised by real content here — it needs a purpose-built fixture. Do not skip it: it was added specifically because `sandbox.tmx` previously lacked that declaration while still rendering correctly in Tiled.
- Templates are read-only during resolution, which is what makes caching them safe. Keep it that way — if merging ever writes into the cached template, the cache becomes a cross-map corruption source.
- Do **not** cache parsed maps. See `DECISIONS.md` Q7: STI mutates the map table in place, including additive layer offsets that would compound on a second load.

## Blocked by

01, 02
