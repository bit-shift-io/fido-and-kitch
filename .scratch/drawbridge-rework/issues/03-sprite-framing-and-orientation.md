Status: done

# The bridge draws 3×3, centred, facing the way it can be crossed

## What to build

Two changes to how the bridge is drawn, both verified from the same captures.

**Framing.** The bridge stays one tile in Tiled and one tile of collision, but draws **3×3 tiles centred on that tile** — one tile of visual bleed in every direction, so the art can key into the surrounding ground rather than stopping at the tile border. This replaces today's framing, which is a 2×2 box centred on the object's *top-left corner* (asymmetric: bridge tile plus above, left, and above-left).

```
sprite box: 3 * object.width  x  3 * object.height
centre:     the object tile's centre
```

Derive both from the object's own dimensions — no hard-coded 96 — so the entity survives a tile-size change. Colliders are untouched: the deck stays one tile, the trigger stays one tile on the arrival side. Visual and physical footprints now differ by design; say so in a comment, because "the sprite covers this tile" stops being a safe inference about what a player can stand on.

The sheet is currently 4 frames of 64×64, so the 3×3 box stretches it 1.5× and will look soft. That is expected and accepted — the sheet gets redrawn at 4 frames of 96×96 (`384×96`) as a follow-up needing no code change. Do not chase the softness.

**Orientation.** A `leftToRight` bridge draws unmirrored — tower on the left, deck lowering rightward across the gap — matching the direction a player can actually walk it. `rightToLeft` draws mirrored. Today both shipped placements draw the tower over the gap with the deck lowering back over solid ground, which reads as the opposite crossing. The entity stops handing the direction property to the sprite as if it were a mirror flag and maps it explicitly:

```
leftToRight -> Sprite{ facing = 'right' }   -- unmirrored
rightToLeft -> Sprite{ facing = 'left'  }   -- mirrored
```

`Sprite`'s `facing` prop keeps its meaning and is not renamed — mirroring is the sprite's concern, direction of travel is the bridge's, and this mapping is the seam. Keep it as a named helper in `drawbridge_support.lua` so it is unit-testable and the inversion is documented where someone will read it.

## Files to create/modify

- `src/entities/drawbridge/drawbridge.lua` (3×3 centred sprite geometry; explicit direction-to-mirror mapping)
- `src/entities/drawbridge/drawbridge_support.lua` (the mapping helper, with a comment on why unmirrored is left-to-right)
- `tests/unit/drawbridge_test.lua` (both mappings; sprite box derived from object dimensions)
- `tests/e2e/drawbridge_test.lua` (captures reviewed for framing and orientation)

## Test approach

The unit tier pins the two cheap, previously-wrong things: the mirror mapping in both directions, and the sprite box being 3× the object's dimensions centred on the tile centre.

Framing and orientation can only be *judged* under real rendering, so the e2e tier is where it is verified: the existing `01_approach` / `02_opening` / `03_open` captures from the correct-side scenario are reviewed by eye. The tower must appear on the approach side with the deck falling across the gap, and the sprite must visibly overlap the neighbouring tiles rather than stopping at the tile border. This is a human check on the captures, not a pixel assertion — call it out in the slice's summary so it actually gets looked at.

The wrong-side e2e scenario is a useful cross-check: it should still fall into the gap, and the raised bridge should look like it belongs to the far side of the pit.

Watch for a false failure in the collision-shaped tests: nothing about the deck or trigger geometry may move. If an integration or e2e scenario about where the player can stand changes behaviour, the collider was resized by mistake.

## Acceptance criteria

- [ ] The sprite draws 3×3 tiles centred on the object tile, derived from `object.width` / `object.height`, with no hard-coded pixel size.
- [ ] Deck and trigger colliders are unchanged at one tile each; no gameplay-affecting geometry moves.
- [ ] A comment states that the visual footprint is deliberately larger than the physical one.
- [ ] `leftToRight` renders unmirrored, `rightToLeft` mirrored — asserted in the unit tier.
- [ ] The mapping lives in a named, commented helper, not inline in the constructor.
- [ ] `res/img/entity_drawbridge.png` is unmodified.
- [ ] e2e captures show the tower on the approach side, the deck lowering across the gap, and the art overlapping the surrounding tiles.
- [ ] All three test tiers pass.

## Blocked by

02 — it maps from the new property values.

## Follow-up (not this slice)

Redraw `res/img/entity_drawbridge.png` as 4 frames of 96×96 (`384×96`) so the 3×3 box renders at 1:1 and the bleed ring can actually be drawn into. No code change required.
