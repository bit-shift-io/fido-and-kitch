# Level Backgrounds — Decision Log (Tiled Background Map)

Grill session 2026-07-10, revised 2026-07-26 for Tiled background map approach.

### Q1: How are backgrounds authored?
**Decision:** Tiled image layers in a separate background map (`res/backgrounds/<name>.tmx`), exported to `.lua`. Map property `background = "name"` selects it.
- **Why:** User already created `night_forest.tmx` with 3 image layers and parallax properties. Tiled is the level editor — authoring backgrounds there is natural. STI natively parses `parallaxx`/`parallaxy`/`offsetx`/`offsety`/`repeatx`. No custom preset format needed.
- **Implication:** Background = data, not code. New background = new `.tmx`/`.lua` pair. Map property selects it.

### Q2: How is the background map loaded and drawn?
**Decision:** Load as second STI map in `Map:new`. Draw its layers in `Map:draw2` before main layers, using STI's parallax formula with `tx`/`ty` from the camera transform.
- **Why:** STI already has parallax logic. The game's `Map:draw2` has the camera transform (`tx`, `ty`). Reusing STI's formula is minimal code. Background map is completely separate from gameplay map — no collision, no entities.
- **Implication:** ~30 lines of code in `Map:new` + `Map:draw2`. No new entity types, no components.

### Q3: Parallax — how does it work without a camera system?
**Decision:** Use the existing draw transform (`tx`, `ty`) from `Map:draw2`. Parallax offset = `tx * parallaxx`. At `parallaxx=0`, layer draws at world position (scrolls with map). At `parallaxx=1`, layer draws at `tx` offset (fixed to screen). At `0.5`, half-speed parallax.
- **Why:** The game already computes `tx`, `ty` to center/scale the map to screen. This IS the camera position. Parallax is just a multiplier on that offset. No camera rework needed.
- **Implication:** Parallax works immediately. Future camera system will unify this but no changes required to background logic.

### Q4: How are background images handled?
**Decision:** Background map's `.lua` references images as `../img/backgrounds/...` relative to `res/backgrounds/`. STI resolves from the map file's directory. Enable `repeatx = true` on all layers for horizontal tiling.
- **Why:** User provided layered PNGs (sky, mountains, forest) — 1200px wide. Maps can be wider. Horizontal tiling covers any map width. STI's `repeatx` handles the draw loop.
- **Implication:** No gradient entity. Full-map coverage via image tiling.

### Q5: What about props, motion, proximity?
**Decision:** Out of scope. User said "strip out all the animation, swaying and fluff. Just parallax layers that move with the camera."
- **Why:** Keep code minimal and self-contained. Props/motion/proximity can be added later as a separate feature.
- **Implication:** No entity files, no motion component, no proximity component, no prop templates/art.

### Q6: Content scope
**Decision:** Sandbox only. Convert sandbox to background map system (set `background = "night_forest"`, remove `sky`/`trees` tile layers). Other maps adopt later. Each implementation slice updates sandbox so it's demoable.
- **Why:** Sandbox is the proving ground; keeps feature focused on the system.

### Q7: Art assets
**Decision:** User provided `night_forest.tmx` + 3 PNGs in `res/img/backgrounds/`. Create `cave` and `sky` background maps as simple variants.
- **Why:** Keeps feature demoable end-to-end; real art already provided.

## Key Assumptions

- STI's parsed background map exposes layers with `parallaxx`, `parallaxy`, `offsetx`, `offsety`, `repeatx`, `image` fields.
- The background map's layer draw order (as declared in TMX) is correct for depth (sky → mountains → forest).
- `Map:draw2`'s `tx`/`ty` are the camera offsets needed for parallax math.
- STI's `repeatx` draws the image repeated horizontally when enabled.

## Trade-offs Explicitly Considered

- **Tiled background map vs Lua presets**: Tiled map wins — authoring in-editor, STI native parallax, user already did it. Lua presets would duplicate STI's capabilities.
- **Separate STI map vs extra layers in main map**: Separate map wins — clean separation (no collision, no entities), reusable across maps, own file. Extra layers in main map would need `collision`/`ladder` properties false and clutter the main map.
- **Parallax via draw transform vs camera rework**: Draw transform wins — minimal, works now. Camera rework is a separate, larger feature.

## CONTEXT.md entries added/updated

- **Background map**, **Image layer**, **Parallax factor**, **Tiling** — see `CONTEXT.md` for definitions and boundaries.