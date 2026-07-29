Status: done

# Load image layers and the parallax background presets

## What to build

All three parallax background presets (`res/backgrounds/{night_forest,mushroom_cave,sky}.tmx`) load directly from `.tmx` and render identically to before. These maps consist **entirely** of image layers and declare **zero tilesets**, so they are the only real content exercising either construct.

This slice also converts the project's second map-construction site. `src/map.lua` loads a background preset through its own `sti()` call, separate from the level-loading path wired up in issue 01.

Scope for this slice:

- **Image layers** — the layer's `image` source resolved project-root-relative, plus `repeatx`/`repeaty`, `parallaxx`/`parallaxy`, `offsetx`/`offsety`, `opacity` and `visible`, in the structure both `Map:setLayer` and the project's own background drawing code consume.
- **Maps with no tilesets** — must produce an empty tileset list and load cleanly rather than erroring or dividing by zero somewhere downstream.
- **Background dispatch** — the background-loading site routes `.tmx` through the parser like the level site does.
- **Differential coverage** — all three presets checked against their preserved golden exports with an empty difference allowlist (none of them use templates).

Not in this slice: templates (04), grouped layers or ellipse/point (05), deleting the background `.lua` exports (06).

## Files to create/modify

- `src/map/tmx.lua` (extend: image layers, zero-tileset maps)
- `src/map.lua` (dispatch at the background-loading site)
- `tests/unit/tmx_test.lua` (extend)
- `tests/integration/tmx_golden_test.lua` (extend with the three presets)
- `tests/fixtures/tmx/` (extend with an image-layer fixture)

## Test approach

**Unit.** Literal XML mirroring `res/backgrounds/night_forest.tmx`: three image layers with differing parallax factors and a large negative `offsetx`. Assert the image path is resolved project-root-relative; that `repeatx`/`repeaty` are emitted as booleans matching the exporter; and critically that **a parallax factor of `0` survives as `0`** — it means a static layer and must not be defaulted to `1`. Also assert a map with no `<tileset>` elements yields an empty tileset list.

**Integration.** Differential checks for all three presets against their goldens, exact match. Then load a level that sets a background and confirm the background map resolves its layers and images through the real stack.

**End-to-end.** The rendered-screenshot tier is the **only** place a background regression is actually visible — the headless tiers never draw. Capture a level with a background and confirm the parallax layers render as before. Treat this as required, not optional, for this slice.

## Acceptance criteria

- [ ] All three background presets load directly from `.tmx` and render identically to before, confirmed by screenshot.
- [ ] Image layer `image`, `repeatx`, `repeaty`, `parallaxx`, `parallaxy`, `offsetx`, `offsety`, `opacity` and `visible` all load in the structure the drawing code consumes.
- [ ] A parallax factor of `0` is preserved as `0`, not defaulted to `1`.
- [ ] `sky`'s `repeatx = true` resolves correctly and still tiles horizontally.
- [ ] A map declaring no tilesets loads cleanly.
- [ ] Image layer image paths resolve project-root-relative.
- [ ] Parser output for all three presets matches their preserved goldens exactly.
- [ ] `./test-unit.sh`, `./test-integration.sh` and `./test-e2e.sh` pass.

## Implementer notes

- The background presets' image paths are relative to `res/backgrounds/`, not `res/map/` — resolve against each `.tmx`'s own directory. `format_path` collapses the `../` segments.
- With a pre-built table passed to STI the directory argument is empty, so `Map:setLayer`'s image-layer branch computes `format_path("" .. layer.image)`. That works **only** if the parser has already made `layer.image` project-root-relative. This is the same condition the tileset `filename` has in issue 01.
- Two consumers read these layers, and they read different fields: STI's own `drawImageLayer`, and the project's background drawing loop in `src/map.lua`, which reads `parallaxx`/`parallaxy`, `offsetx`/`offsety`, `opacity` and `repeatx` directly. Satisfy both — the golden diff will catch a field only one of them uses.
- STI replaces `layer.image` with a loaded image object during `setLayer`, so the differential comparison must run on the parser's output *before* it is handed to STI, not on a loaded map.

## Blocked by

01
