# Decisions — Direct `.tmx` Map Loading

Grill session 2026-07-29, immediately following the external-tileset work. Prompted by two consecutive real Tiled re-exports of `sandbox.tmx` silently blanking the `type` field on every template-placed object — the first of which caused **zero players to spawn** (the spawn point's type was emptied, so nothing matched the spawn entity), and left the drawbridge, coin, cage, exit, switch, key, jump pad and push box as inert scenery. Hand-repairing the exported `.lua` after each Tiled edit was rejected as unsustainable.

### Q1: How much of the `.tmx` format should we take over?
**Decision:** Full `.tmx` parsing, with the `.lua` loading path retained permanently as a fallback, dispatched by file extension.
- **Why:** Three options were weighed. A *template-resolution-only* fix (keep loading the exported `.lua`, but read the `.tmx`/`.tx` at load time purely to repair the dropped `type`) is much smaller — but it still requires parsing `.tmx` XML to map object id → template path, so it pays most of the parsing setup cost while leaving the export step, the committed derived artefact, and the whole "did you re-export?" failure class in place. Full replacement removes the entire category of bug rather than the one instance of it.
- **Why the `.lua` fallback is not optional:** There are **18 hand-authored `.lua` fixture maps** with no `.tmx` counterpart — 17 under `tests/fixtures/` plus `res/map/drawbridge_fixture.lua` — several carrying comments explicitly stating that no Tiled GUI was available and the Lua is to be edited directly. Dropping `.lua` support would require inventing `.tmx` sources for all of them, which defeats the reason they exist.
- **Implication:** Two map formats coexist by design, not by transitional accident. `.tmx` for Tiled-authored content, `.lua` for hand-written fixtures.
- **Alternatives considered:** Template-resolution-only (rejected — leaves the export step and its failure modes); full replacement with no `.lua` fallback (rejected — would orphan 18 fixtures).

### Q2: What happens to the exported `.lua` files, and how does the level select enumerate maps?
**Decision:** Delete the `.lua` exports that have a `.tmx` source; level enumeration recognises both extensions.
- **Why:** With `.tmx` loading directly, a committed export is a derived artefact that can silently disagree with its source — a state the repository has already been in. Deleting them makes the `.tmx` the single source of truth. Enumerating both extensions keeps hand-authored fixtures discoverable.
- **Implication:** The Tiled export directive inside each map file can be removed. Test helpers that discover maps by globbing for `.lua` must be updated too, or they will silently stop covering the real maps — a false-pass risk, since a test that finds zero maps to load still passes its per-map assertions.
- **Alternatives considered:** Keep the exports during a transition period (rejected — invites divergence and needs a de-duplication rule in the menu); delete exports but enumerate only `.tmx` (rejected — would force `drawbridge_fixture.lua` to be converted or relocated).

### Q3: How much of the Tiled format should the parser support, and what happens on the rest?
**Decision:** Support what the project uses plus a small forward-looking set; hard-error on everything else, naming the file and the construct.
- **Why:** Matches the loud-failure convention established in the external-tileset work (a broken map is broken either way, so surfacing it at load beats shipping a level with invisible content). Building the full format including constructs no map exercises would be unexercised surface area.
- **Alternatives considered:** Implement everything the vendored library can render (rejected — large untested surface); warn-and-continue on unsupported constructs (rejected — would ship a level silently missing a layer, the exact failure mode this whole feature exists to eliminate).

### Q3a: Which specific constructs, given that "only what's used" would hard-error on things we may reach for?
**Decision:** Add **grouped layers** and **ellipse/point objects** to the supported set despite being unused today. Keep **CSV** rejected. Include **polygon** as a zero-cost freebie.
- **Why:** Grouped layers are the natural way to organise a map as it grows, and the vendored library already flattens them. Ellipse and point are standard Tiled drawing tools that would hard-error the first time someone chose one over a rectangle. Polygon shares the polyline parser and is already handled downstream, so excluding it would cost more code than including it.
- **Why CSV stays rejected:** Tile layer format is a Tiled *project preference*. Flipping it would break every map at once — which is precisely when a loud, legible, immediate failure is most valuable, rather than silently accepting a second code path that nothing tests.
- **Verified:** Only `<polyline>` is used across all maps (7 instances across two maps). No map uses polygon, ellipse, point, grouped layers, infinite/chunked data, or CSV.

### Q3b: Image layers — support now or hard-error?
**Decision:** Support them. Mandatory, not optional.
- **Why:** Initially assessed as a dormant code path and a candidate for rejection. Investigation proved otherwise: the parallax background system loads `res/backgrounds/<name>.lua` as a Tiled map through a **second** map-construction site, and those presets consist *entirely* of image layers. Image layers are live production content on every level that sets a background. Rejecting them would have broken every level's background.
- **Implication:** This was very nearly planned as an unsupported construct. It is the strongest argument in this session for verifying "unused" claims against the code rather than accepting them.
- **Details that must be preserved:** `repeatx` is genuinely used (by the `sky` preset); a parallax factor of `0` is meaningful (a static layer) and must not be defaulted to `1`; layer offsets are large negative values.

### Q4: Do the background presets convert too?
**Decision:** Yes — both map-construction sites route by extension, and the background `.lua` exports are deleted along with the level ones.
- **Why:** One map format across the project rather than two workflows. The background presets also provide the *only* real-content coverage for image layers and for maps that declare **zero tilesets** — constructs no map under `res/map/` exercises — so converting them strengthens the test suite rather than merely widening scope.
- **Implication:** Larger blast radius: a parser defect could break every level's background. Mitigated by the rendered-screenshot test tier, which is the only place a background regression is actually visible.
- **Scope correction:** This raised the feature from 4 `.tmx` files to **7**, and from one dispatch site to two.

### Q5: How are object templates resolved?
**Decision:** Follow Tiled's own semantics — instance attributes override template attributes, custom properties merge with the instance winning, and a template's tile reference is remapped by `templateGid − templateFirstgid + mapFirstgidForThatTileset`.
- **Verified against real data, not assumed:** All eleven template instances in `sandbox.tmx` were checked against the remapping formula and the last known-good export. Every one matches: `spawn.tx` gid 1 → 145, `push_box.tx` 2 → 146, `pressure_switch.tx` 3 → 147, `switch.tx` 4 → 148, `key.tx` 5 → 149, `exit.tx` 6 → 150, `coin.tx` 7 → 151, `teleport.tx` 9 → 153, `cage.tx` 10 → 154, `jump_pad.tx` 11 → 155, `drawbridge.tx` 12 → 156.
- **Key finding:** This proves Tiled's exporter resolves `name`, `gid`, `width` and `height` through templates **correctly**. The dropped `type` is its *only* defect here. That narrowed the bug from "template resolution is broken" to a single precise field, and is why the differential test's expected delta is enumerable rather than open-ended.
- **Implication:** The parser must also accept both the modern and legacy spellings of the class/type attribute. Tiled's 1.9 rename of object "type" to "class" is the most plausible origin of the exporter defect, and the affected map is written in a format version older than the Tiled version writing it — a version-drift smell that makes accepting either spelling cheap insurance.

### Q6: What if a template references a tileset the map does not declare?
**Decision:** Auto-register it — load the tileset and append it to the map's tileset list, allocating its tile-numbering offset deterministically after the existing tilesets.
- **Why:** This is not hypothetical. `sandbox.tmx` did not declare the props tileset until it was added by hand during the preceding external-tileset work, yet Tiled rendered it correctly the whole time, because templates carry their own tileset reference. Requiring a declaration would mean a map that is valid in Tiled refuses to load in the game, with a manual `.tmx` edit as the only fix.
- **Implication:** Any map that opens correctly in Tiled loads correctly in the game — a much stronger and more predictable guarantee than "loads if the tileset list happens to be complete". Costs deterministic offset allocation logic.
- **Alternatives considered:** Require the declaration and fail loudly (rejected — valid-in-Tiled maps would refuse to load, and the fix is manual XML editing).

### Q7: Should the parsed `.tmx` be cached the way resolved `.tsx` tilesets are?
**Decision:** Cache parsed **templates**; do **not** cache parsed maps.
- **Why not maps:** The loader mutates the map table in place and extensively — it attaches a metatable; replaces tile layer data *twice* (encoded string → decoded identifier list → grid of live tile references); accumulates layer offsets **additively**, so a second load of a cached table would double-offset every layer; attaches draw/update closures capturing that specific map instance; rewrites grouped layer names, so a reload would compound them; injects layer-name keys into the layer list; computes object vertex data; and has entity references attached to objects. Safe reuse would require a deep copy on every retrieval, costing more than a re-parse and introducing cross-load aliasing bugs.
- **Measured, not assumed:** Parsing the largest map (`sandbox.tmx`, 9.6 KB) with the vendored XML library averages **2.37 ms** over 50 runs. That is well inside a 16.7 ms frame, against a level load dominated by image decoding and collider construction. There is no performance problem to solve.
- **Why templates yes:** They are small, genuinely repeated (12 template files; `sandbox` alone has 11 references including `teleport.tx` twice, and the same templates recur across maps), and only ever *read* during resolution — merging builds fresh object tables, so nothing aliases.
- **Alternatives considered:** Cache parsed maps with deep-copy-on-read (rejected — slower than re-parsing and strictly riskier); no caching at all (rejected — template re-parsing is pure waste and trivially avoidable).

### Q8: How much of the vendored library must be patched?
**Decision:** None. All new code lives in project source; the vendored library's patch does not grow by a line.
- **Why this works:** The library's constructor already accepts a pre-built map table in place of a file path. So dispatch happens in project code: on a `.tmx` extension, parse to a table and pass the table; on `.lua`, pass the path exactly as today. Verified there are exactly two construction sites (levels and background presets) and that the constructor's directory argument is used only for tileset image paths — already branched on the external-tileset marker by the existing patch — the image-collection atlas cache key, and image layer paths.
- **Condition this imposes:** The parser must emit every asset path resolved relative to the project root and mark tilesets as externally referenced. This is already exactly how the external-tileset resolver emits paths, so it is consistency rather than a new constraint.
- **Why it matters:** The library is git-ignored and reconstructed by the setup script from an upstream clone plus patches. Every line added to that patch is a line that can conflict on an upstream update and that lives outside normal review. Keeping the parser in project source keeps it version-controlled and unit-testable.
- **Known minor consequence:** With no directory argument, the image-collection atlas cache key loses its directory prefix. Since that key then identifies the tileset by name alone, maps sharing a tileset share one atlas — desirable. A collision would need two *different* tilesets with the same name, which Tiled discourages. Accepted and recorded rather than engineered around, since avoiding it would require patching the library.

### Q9: How is this tested, given the surface is much larger than the external-tileset resolver?
**Decision:** Differential tests against preserved real Tiled exports, **plus** per-construct unit tests on literal XML.
- **Why both:** Six maps exist as both `.tmx` and exported `.lua`. Preserving those exports as goldens gives a field-by-field check against *genuine Tiled output* rather than fixtures invented to match the implementation — which is what makes it meaningful, and what catches the default-materialisation details that are easy to get subtly wrong and invisible in play. For the two template-free maps the match is exact; for the rest it is exact except the enumerated dropped-type delta, which simultaneously verifies the fix and documents the bug. But goldens alone would leave error paths and rejected constructs untested (they have no golden by definition) and would report failures as "the whole map differs" rather than naming a construct — hence the unit tier.
- **Implication:** The exports must be copied to a golden fixture location **before** being deleted, otherwise the reference is lost to git history and the differential tier cannot be written.
- **Alternatives considered:** Unit tests plus the existing whole-project checks only (rejected — nothing would pin output shape field-by-field against real exporter output); goldens only (rejected — no error-path coverage, poor failure localisation).

## Assumptions

- The vendored XML library's tree handler is sufficient for `.tmx` and `.tx` grammar. Higher confidence than for the external-tileset work, since it is now proven against real `.tsx` files in production and was measured parsing `sandbox.tmx` successfully during this session.
- All `.tmx` files in the project use base64-uncompressed tile data with no compression attribute — verified across all seven. The zlib/gzip paths therefore inherit for free but arrive unexercised by real content.
- The preserved exports for the two template-free maps are correct Tiled output, making them trustworthy goldens. The template-bearing maps' exports are correct *except* for the dropped `type` fields.
- No map uses a construct outside the supported set — verified by inspecting all seven `.tmx` files.

## Trade-offs

- Owning a `.tmx` parser means owning compatibility with Tiled's format across future Tiled versions, where previously that burden sat with Tiled's own exporter. Accepted because the exporter has demonstrably failed at exactly that job, silently, twice in one day, and because the parser only needs to track the subset this project uses.
- Deleting the exported `.lua` files removes an at-a-glance readable view of each map's data. Accepted: that view was actively misleading, since it could disagree with the source it was derived from.
- Emitting still-encoded tile layer data looks like an odd half-measure and will read as unfinished to someone unfamiliar with the reasoning. Accepted for the large payoff — zero downstream changes and free reuse of existing decode handling — and documented in the ADR precisely because it is surprising.
- Auto-registering a template's undeclared tileset means a map's effective tileset list can differ from what its own XML declares. Accepted because it matches Tiled, and the alternative refuses maps Tiled considers valid.
- Two permanent map formats is more surface than one. Accepted: the hand-authored fixtures are not Tiled-authored and should not pretend to be.

## Measurements

- `sandbox.tmx` (9.6 KB, largest map): **2.37 ms** average parse over 50 runs with the vendored XML library under LuaJIT. Well inside one frame.
- Map file inventory: 7 `.tmx` files (4 levels, 3 background presets); 6 have `.lua` exports; 18 hand-authored `.lua` fixtures have no `.tmx`.
- Template usage: 12 `.tx` files; 11 instances in `sandbox.tmx`, 1 in `ll2.tmx`, 0 elsewhere.
- Custom property types in real use: object, file, bool, int, and untyped strings. Float and color are unused but included, as the coercion is a single shared branch.

## Discovered defects and stale content

Recorded because each was found during this session and each needs handling during implementation.

- **`tiny.tmx` is broken and unreachable.** It references `../generic_platformer_tiles.tsx`, which resolves to a path that does not exist (the real tileset lives one directory deeper). It is authored against Tiled 1.5.0 while every other map is 1.12.2, and it has no `.lua` export, so enumeration has never found it. Once enumeration includes `.tmx` it becomes reachable and will hard-error under the fail-loudly rule. Must be repointed at the correct path or deleted — **not** left to break map enumeration.
- **Latent aliasing in the external-tileset cache.** The resolver returns a shallow copy of its cached entry, so the nested per-tile tables are shared by reference between the cache and every map using that tileset — and those references reach the tile custom-property accessor. Nothing mutates them today, so it is latent rather than live, but this feature reasons directly about caching and copy semantics and should close it.
- **`CONTEXT.md` contains a now-false statement.** The existing *External tileset* entry asserts that object templates "already resolve correctly regardless of embedding". That is exactly the defect this feature exists to fix, and it must be corrected rather than left to mislead.

## CONTEXT.md entries added

- **Tiled map source** — new.
- **Object template** — new.
- **External tileset** — corrected: the claim that templates already resolve correctly is false and is replaced.
