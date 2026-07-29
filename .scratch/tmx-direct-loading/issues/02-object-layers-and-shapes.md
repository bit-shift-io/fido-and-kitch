Status: done

# Load object layers, object shapes and a full real level

## What to build

`res/map/ll1.tmx` loads directly from its `.tmx`, plays and collides identically to the exported version it replaces. This is the first real level to load without an export, and the first map the differential test harness can check field-for-field: `ll1` places no template instances, so its preserved export is trustworthy Tiled output and the parser's table must match it **exactly**.

Scope for this slice:

- **Object groups** — the layer itself (name, id, `draworder`, properties, and the same default materialisation as tile layers) and its objects.
- **Object attributes** — `id`, `name`, `type`, `x`, `y`, `width`, `height`, `rotation`, `gid`, `visible`, `opacity`, and per-object custom properties via the coercion helper from issue 01. Accept both the modern and legacy spellings of the class/type attribute, per `DECISIONS.md` Q5.
- **Object shapes** — a plain object becomes a rectangle; `<polyline>` and `<polygon>` become their respective shapes with a parsed point list in the structure the exporter emits and `Map:setObjectCoordinates` consumes. `ll1.tmx` has four polylines (waypoint paths), so this is exercised by real content.
- **The differential test harness** — load a preserved golden export, parse the corresponding `.tmx`, and compare the two tables recursively, reporting the specific differing path rather than "the tables differ". This harness is reused by issues 03 and 04, so it needs to support an explicit allowlist of expected differences (issue 04 needs it for the dropped-type delta) even though `ll1` requires an empty allowlist.
- **Loud failures** for an unrecognised object shape and an unrecognised property type.

Not in this slice: templates (04) — note `ll2.tmx` has one template instance and so cannot be converted until then. Ellipse and point shapes are issue 05.

## Files to create/modify

- `src/map/tmx.lua` (extend: object groups, object attributes, rectangle/polyline/polygon shapes)
- `tests/support/` (new differential-comparison helper, alongside the existing test support modules)
- `tests/integration/tmx_golden_test.lua` (new) and register it in `tests/integration/run.lua`
- `tests/unit/tmx_test.lua` (extend)
- `tests/fixtures/tmx/` (extend with object/shape fixtures)

## Test approach

**Unit.** Literal XML for: an object group with several objects; each object attribute including defaults for omitted ones (an object with no `name`/`type` must produce empty strings, not nil); both class/type attribute spellings; a polyline and a polygon producing correctly parsed point lists; per-object properties merging in the exporter's shape. Then the two new loud failures — unrecognised shape, unrecognised property type — each naming the file and construct.

Mirror the structure of `ll1.tmx`'s real object groups (`ladder`, `game`, `waypoints`) in the fixture XML rather than inventing a simpler layout, so real Tiled output quirks are covered — in particular the fractional coordinates real maps contain.

**Integration.** Two things:

1. **Differential** — `ll1.tmx` parsed against its preserved golden export, asserting an **exact** match with an empty difference allowlist. This is the strongest single test in the feature: it pins every default-materialisation and shape-parsing detail against real exporter output, and is the class of check that catches subtle errors invisible in play.
2. **Real stack** — `ll1.tmx` loads through the harness, steps frames, spawns its players, and its collision geometry behaves as before.

## Acceptance criteria

- [ ] `res/map/ll1.tmx` loads directly through the real stack, steps frames without error and spawns players.
- [ ] The parser's output for `ll1.tmx` matches its preserved golden export exactly, with no allowlisted differences.
- [ ] Object groups and every object attribute load, with omitted attributes materialised to the exporter's defaults.
- [ ] Rectangle, polyline and polygon shapes load in the structure `Map:setObjectCoordinates` consumes; `ll1.tmx`'s four waypoint polylines resolve correctly.
- [ ] Both class/type attribute spellings are accepted on objects.
- [ ] An unrecognised object shape or property type raises an error naming the file and the construct.
- [ ] The differential harness reports the specific differing field path and supports an expected-difference allowlist.
- [ ] `./test-unit.sh` and `./test-integration.sh` pass.

## Implementer notes

- Objects with a `gid` are anchored differently from plain rectangle objects — see the anchoring comment in `src/components/pushable/pushable_support.lua`, which documents that a tile object's `y` is its bottom edge while a plain rectangle's is its top. Do **not** normalise this in the parser: the exporter does not, and the golden diff will fail if you do. Downstream code already handles both.
- `ll1.tmx`'s waypoint objects have no `width`/`height`. Check what the exporter emits for those (the golden is the authority) rather than assuming zero.
- Real maps contain fractional coordinates. Compare numerically with a tolerance in the differential harness rather than by string equality, or trivially-equal floats will read as differences.

## Blocked by

01
