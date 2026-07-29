Status: pending

# Support grouped layers and ellipse/point objects

## What to build

The two forward-looking constructs from `DECISIONS.md` Q3a: grouped layers, and ellipse and point object shapes. No map in the project uses either today — they are supported now because grouped layers are the natural way to organise a map as it grows and ellipse/point are standard Tiled drawing tools, and hard-erroring the first time someone reaches for one would be a poor authoring experience.

Because there is no real content to validate against, this slice's verification rests on purpose-built fixtures loading through the real stack.

Scope for this slice:

- **Grouped layers** — a `<group>` containing other layers, emitted in the structure `Map:groupAppendToList` expects. That function flattens groups, prefixing child layer names with the group's name and compounding visibility, opacity and offsets down into children. The parser's job is only to emit the nested group; STI does the flattening.
- **Nested groups** — a group inside a group, since STI's flattening recurses and Tiled permits it.
- **Ellipse objects** — an `<ellipse/>` child marks the object as an ellipse shape.
- **Point objects** — a `<point/>` child marks the object as a point shape.

Both shapes must be emitted in the form `Map:setObjectCoordinates` consumes, alongside the rectangle/polyline/polygon shapes from issue 02.

## Files to create/modify

- `src/map/tmx.lua` (extend: `<group>` recursion, ellipse and point shapes)
- `tests/unit/tmx_test.lua` (extend)
- `tests/integration/tmx_test.lua` (extend)
- `tests/fixtures/tmx/` (extend with a grouped-layer fixture and a shapes fixture)

## Test approach

**Unit.** A `<group>` containing a tile layer and an object group emits a group layer with both children nested, carrying its own name, id, visibility, opacity, offsets and properties. A group nested inside a group emits correctly. An `<ellipse/>` and a `<point/>` object each produce the right shape marker, with a point object's zero width and height matching what the exporter emits.

**Integration.** A fixture `.tmx` whose layers are wrapped in a group loads through the real stack, and after STI's flattening the child layers are reachable under their prefixed names and the game's layer-driven behaviour still works — specifically that a collision object group inside a group still builds colliders, since collision layers are identified by a layer property and grouping must not break that lookup. A second fixture containing ellipse and point objects loads without error.

## Acceptance criteria

- [ ] A grouped layer loads, and STI's flattening produces the child layers under their prefixed names.
- [ ] A nested group loads correctly.
- [ ] A collision object group inside a group still builds colliders through the real stack.
- [ ] Group visibility, opacity and offsets propagate to children as STI's flattening expects.
- [ ] Ellipse and point objects load with the correct shape in the structure `Map:setObjectCoordinates` consumes.
- [ ] `./test-unit.sh` and `./test-integration.sh` pass.

## Implementer notes

- Read `Map:groupAppendToList` in the vendored loader before writing the group emitter — it mutates child layers in place, renaming them to `parent.child` and folding the parent's opacity and offsets into them. Emitting the wrong nesting shape produces layers that vanish rather than an error.
- Grouping changes layer **names**, which is how this project looks layers up (`self.layers[layer.name]`). A collision layer moved into a group becomes `groupname.collision`. Worth confirming the collision/ladder/kill layer lookups key off the layer *property* rather than the name — if any keys off the name, note it, because grouping a level's layers would then silently disable that behaviour. This is exactly the kind of interaction the integration test above exists to catch.
- No golden export exists for these constructs, so unlike issues 02–04 there is no differential check available. The fixtures are the only specification — build them to mirror how someone would actually organise a real level in Tiled.

## Blocked by

01, 02
