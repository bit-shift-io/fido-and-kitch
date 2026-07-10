# Level Backgrounds — Decision Log

Grill session 2026-07-10.

### Q1: Scrolling camera / parallax in scope?
**Decision:** Self-moving backgrounds only; design for parallax later via a `depth` property on every background element. No camera work in this feature.
- **Why:** The game currently draws the whole map to a fit-to-screen canvas with no scrolling camera (the hump Camera instance is never used for drawing), so classic parallax has nothing to scroll against. A camera/auto-zoom rework is planned separately and will change core rendering for all levels.
- **Implication:** `depth` is stored and plumbed but visually inert. When the camera lands, parallax becomes a multiply of `depth` into the draw offset — no redesign.
- **Alternatives considered:** Bundling the camera rework into this feature — rejected as it doubles the scope and risk of a decoration feature; user agreed with the recommendation to keep them separate.

### Q2: How are backgrounds authored in the map?
**Decision:** Objects in a `background` objectgroup layer, spawned through the existing `Map:loadEntity` pipeline. Props are **tile objects from Tiled templates backed by the `props` image-collection tileset**.
- **Why:** User wanted "objects — good and simple" and asked whether the editor could show a texture per object. It can: the existing templates (teleport, cage, coin) are already tile objects (`gid` set), and `res/tilesets/props.tsx` is already an image-collection tileset containing `tree_1.png`. Referencing props.tsx tiles from templates shows the actual art at actual size in Tiled.
- **Implication:** New PNGs (cloud, bush) are added as tiles to props.tsx; one `.tx` template per prop with predefined type and default properties. Level authors drag templates and tweak properties — no code changes per placement.
- **Alternatives considered:** Tiled-native image layers for clouds/backdrops (idiomatic in other Tiled games, STI parses them) — rejected in favour of a single uniform object mechanism; map-level properties for everything — rejected except where noted below.

### Q3: How is the sky gradient defined?
**Decision:** A rect object with `type=gradient`, colour properties (`colorTop`, `colorBottom`), and a `coverMap` boolean.
- **Why:** Consistent with "objects for everything". Tiled has no native gradient concept, so it can't be previewed either way; the object just carries data. `coverMap=true` removes the need to size the rect exactly.
- **Implication:** Multiple gradient regions are possible (coverMap=false rects), though full-map is the expected use.
- **Alternatives considered:** Map custom properties (`skyColorTop`/`skyColorBottom`) — recommended by Claude for being un-losable, but user preferred the object with a cover-map checkbox.

### Q4: How do clouds work?
**Decision:** A `cloud_spawner` rect object that populates its region with clouds drawn from a **pool of Tiled templates** (via `file` properties pointing at `.tx` files); spawned clouds drift and **wrap around the map edges**.
- **Why:** User wanted less manual placement than per-cloud objects, plus the ability to feed the spawner a template (or pool) of what to spawn.
- **Implication:** Stable population — the spawner seeds `count` clouds at load with randomized template/position/speed/scale; wrap-around means no despawn/respawn logic. The template-pool mechanism generalizes to future spawners.
- **Alternatives considered:** Individually placed clouds with wrap (max author control, more placement work); continuous spawn/despawn at edges (more code, population drift).

### Q5: How do props animate (single-frame art)?
**Decision:** Both options, composable per prop: procedural motion (sine sway for trees; triggered shake/squash for bush rustle) and frame animation via the existing Sprite + Timeline components.
- **Why:** Procedural works with the single-frame art we have today; frame animation unlocks richer art later; user explicitly wanted the ability to use one or both together.
- **Implication:** Motion is parameterized (strength, speed) and wind-driven; frame animation is opt-in via template/object properties.

### Q6: How is "player runs past the bush" detected?
**Decision:** A generic **proximity component** in the components directory, configured with a radius; it monitors player distance and fires enter/exit signals the prop reacts to.
- **Why:** User framed it as "like a component?" — matches the existing entity/component architecture. One mechanism reused by any future reactive prop.
- **Implication:** Uses the established player-position/world-query patterns (cf. `checkForUsables`, `queryLadder`) read-only; background props still create no colliders.
- **Alternatives considered:** Bespoke detection per entity type — rejected; every new reactive prop would need new detection code.

### Q7: Wind — global or per-object?
**Decision:** Global per-map wind (custom property, e.g. `windX`) × per-object multiplier (`windScale`), **with a code default when the map defines nothing**.
- **Why:** One value retunes a whole level (calm ↔ stormy) while keeping per-object variety; the default means backgrounds work with zero map configuration.
- **Implication:** Wind drives both cloud drift velocity and sway strength, so the level feels coherent.

### Q8: Content scope
**Decision:** Sandbox only. Convert sandbox to the new system (replace its `sky`/`trees` tile layers); ll1 and other maps adopt it later as content work. **Each implementation issue updates the sandbox map as part of its slice** (user directive at sign-off).
- **Why:** Sandbox is the proving ground; keeps the feature focused on the system.
- **Implication:** Every slice is demoable in sandbox as it lands; the dual-file rule (edit Tiled source + re-export Lua) applies to every issue.

### Q9: Art assets
**Decision:** Create simple placeholder PNGs in-repo (cloud shapes, a bush); reuse `tree_1.png`.
- **Why:** Keeps the feature demoable end-to-end; real art swaps in later without code changes (templates/tileset entries just point at new files).

## Key assumptions

- STI's parsed object data exposes template-resolved properties and `gid` tile references well enough to spawn props (the existing template-based entities — teleport, cage — already rely on this).
- Tiled `file` properties are a workable way to reference `.tx` templates from a spawner object; the game resolves them to prop definitions at load.
- The `background` objectgroup being first in layer order is sufficient for correct draw order under the current renderer (layer order = render order; players drawn after the map).

## Trade-offs explicitly considered

- **Uniform object mechanism vs Tiled-native image layers**: image layers get parallax/repeat for free in Tiled but split authoring across two mechanisms; uniformity won.
- **Depth-now/parallax-later** carries a small risk the future camera design invalidates the depth semantics; accepted because the property is one number and cheap to migrate.

## CONTEXT.md entries added

- **Background prop**, **Gradient object**, **Cloud spawner**, **Wind**, **Depth**, **Proximity component** — see `CONTEXT.md` for definitions and boundaries.
