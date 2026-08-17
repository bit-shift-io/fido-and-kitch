# Fido and Kitch — World-Edge Frame & Void Fill: Confirmed Requirements

Grill notes (2026-08-17). Feature: a nice dividing graphic where the game
world ends but the screen continues. The camera's view rect can extend past
the map bounds (`Camera.computeFraming`, `src/camera.lua:82-92`) when the
screen aspect ratio doesn't match the map's, producing empty screen strips
outside the world (vertical strips for wide screens, horizontal for tall).

## Confirmed decisions (asked + answered)

1. **Divider type**: a border **frame at the world's edge** — the playfield
   reads as a framed diorama. Not a fade/vignette, pattern void, or world
   extension.
2. **Void fill**: a **generic tiling background** fills the out-of-world
   screen area (the strips) ONLY. It is clipped/scissored to the 4 strips
   outside the projected world rect so it never shows through transparent
   gaps in a map's own backdrop. All maps have a background of their own.
3. **Parallax scope**: parallax backgrounds are "for view in the player
   world, not outside of it." Today `ParallaxRenderer:drawBackground`
   (`src/map/parallax_renderer.lua:34`) scales the image to cover the whole
   screen, so it currently bleeds into the void — it must be clipped to the
   world rect.
4. **Frame art**: custom art. **Edge-tile + 4 corner pieces + ornaments**
   ("ornaments" is the name for the interstitial decorative pieces; corners
   are "corner pieces"). Tiled edge texture per side; a hero asset at each
   corner; extra ornaments along each border hide the tiling repetition.
5. **Frame space**: **world space** — art tiles repeat at world scale and
   zoom with everything else. No projection math; reuses the world transform.
6. **Config**: one global code config, **the same for all maps** — it's part
   of the game, not world settings. **No seeds / no randomization** — fully
   deterministic, identical dressing every map and every frame.
7. **Ornament selection**: **pre-configured percentage-based** — each side's
   pool is a list of `{img, weight}` pairs; ornaments are distributed along
   the edge proportionally to the weights, in a fixed deterministic pattern.
8. **Frame placement**: **centered on the world boundary**; drawn after the
   world tiles; gameplay entities draw over it (existing entity-over-map
   order in `InGameState:draw` already supports this).

## Proposed config shape (code)

> Superseded by `Diorama.config` in `src/diorama.lua` (system renamed from
> "border" to **Diorama**; the asset folder is `res/img/diorama/`; the final
> config uses `frame.tileSize` (band width, default 16), `frame.outset`
> (frame line pushed out from the world boundary, default 8),
> `frame.ornaments.corners` (corners are ornaments, a subsection of
> `ornaments`), and a fixed small
> `frame.ornaments.<side>.count` of discrete ornaments per edge — never a
> spacing-driven tiled row — with a 1:1 tile band where a texture's short
> dimension maps to `tileSize` and its long dimension repeats along the full
> edge). The sketch below is kept for provenance only.

```lua
border = {
  tiles     = { top="...", bottom="...", left="...", right="..." },
  corners   = { topLeft="...", topRight="...", bottomLeft="...", bottomRight="..." },
  spacing   = 64,                    -- px between ornament slots
  ornaments = {
    top    = { {img="...", weight=0.4}, {img="...", weight=0.3}, {img="...", weight=0.3} },
    bottom = {...}, left = {...}, right = {...},
  },
}
```

## Placement algorithm (sketch)

- Slot count per edge = `floor(edgeLen / spacing)`; corners are their own
  pieces at the 4 corners; ornaments fill the slots by weighted draw,
  deterministic (no per-map seed).
- Slots/ornaments/corners drawn in world space at the world edge.

## Render layering (world → screen)

1. Void tiling (screen space, clipped to the 4 strips outside the world rect)
2. Map parallax background (clipped to the world rect — needs scissor)
3. World tiles (existing `map:draw2`)
4. Frame (world space: edge tiles + corners + ornaments, centered on the
   world boundary)
5. Entities (existing `map:drawEntities`, over the frame)

## Open / assumed

- Void tiling is assumed **static screen-space** (fixed to screen, not
  scrolling, not aligned to the world grid).
- The frame shows whenever its edge is on screen — including overview /
  game-over full-map views (fine by design).
- Art assets do not exist yet; the config keys are the contract (`Diorama`
  skips a missing image with a memoized `Log.warn` so the game runs before
  art lands). The void texture exists at
  `res/img/diorama/diorama_void.png`.
- Implementation home: `src/diorama.lua` (stateless singleton, `Diorama.config`
  + `drawVoid`/`drawFrame`, pure geometry under `Diorama._internal`), wired
  into `InGameState:draw` between the void fill / `map:draw2` /
  `map:drawEntities` calls; the parallax scissor lives in
  `src/map/parallax_renderer.lua`.
