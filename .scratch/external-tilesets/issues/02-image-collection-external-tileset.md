Status: done

# Resolve an image-collection external tileset, including cropped tiles

## What to build
A map referencing an external image-collection `.tsx` tileset (`columns = 0`, one `<image>` per `<tile>` — e.g. `res/tilesets/props.tsx`) resolves each tile's correct image, including tiles that crop a sub-region of a larger source image (a `<tile>` with `x`/`y`/`width`/`height` distinct from its `<image>`'s own `width`/`height` — e.g. `props.tsx` tile id `3`, which crops a 162×162 region out of the 488×162 `switch.png`).

## Files to create/modify
- src/map/external_tileset.lua (extend: image-collection shape, per-tile image + optional crop rect)
- tests/unit/external_tileset_test.lua (extend)
- tests/fixtures/ — extend or add a fixture using an image-collection tileset (can reference `res/tilesets/props.tsx` directly, or a smaller dedicated fixture `.tsx` if `props.tsx` is too large/likely to change)

## Test approach
Headless unit: given literal XML mirroring `props.tsx`'s actual shape (including at least one uncropped tile like id `1`, and one cropped tile like id `3`), `external_tileset` returns per-tile entries with the right image path and, for cropped tiles, the right sub-region. Integration: a fixture map placing an object using this tileset loads and renders the correct cropped region (verify via the e2e screenshot tier if a visual check is warranted, otherwise integration-tier load-without-error is sufficient given this shape has no gameplay logic riding on it yet).

## Acceptance criteria
- [ ] An image-collection external tileset resolves each tile's image correctly.
- [ ] A cropped tile (source region smaller than the referenced image) resolves the correct sub-region, not the whole image.
- [ ] An uncropped tile (no `x`/`y`/`width`/`height` on the `<tile>`) resolves the whole referenced image.
- [ ] `./test-unit.sh` and `./test-integration.sh` pass.

## Blocked by
01
