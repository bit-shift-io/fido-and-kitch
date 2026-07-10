# Level Backgrounds — Handoff

## Summary

A background system authored entirely in the map: a `background` objectgroup layer holds a gradient rect object (`colorTop`/`colorBottom`, `coverMap` checkbox), a `cloud_spawner` rect that populates its region from a pool of Tiled templates with wind-driven, map-wrapping drift, and prop tile objects (tree, bush) placed from templates backed by the `props.tsx` image-collection tileset so real art shows in the Tiled editor. Props support composable motion — procedural (wind-driven sine sway; triggered shake/squash) and/or frame animation via the existing Sprite + Timeline components — and a new generic `Proximity` component lets any prop react to a nearby player (bush rustles on pass). A global map `windX` property (code default when absent) × per-object `windScale` drives clouds and sway together. Everything is pure visuals: no colliders, never obstructs the player. All elements carry a `depth` property, stored but visually inert until the future camera rework enables parallax. Scope: system + sandbox conversion only.

## Suggested implementation order

1. **01-gradient-background** — establishes the `background` layer convention, non-collider background entities, and `depth` plumbing everything else reuses.
2. **02-static-props-from-templates** — prop entities, placeholder art, props.tsx tiles, templates.
3. **03-wind-and-procedural-sway** and **04-proximity-bush-rustle** — independent of each other; either order or interleaved.
4. **05-cloud-spawner** — needs art (02) and wind (03).
5. **06-frame-animation-and-sandbox-conversion** — last; removes the old sky/trees tile layers once everything is in place.

Per the user's directive: **every issue updates the sandbox map as part of its slice** (each slice is demoable in sandbox when done).

## Key integration points (verified at planning time)

- Entity spawn from TMX objects: `Map:createEntitiesFromObjectGroupLayers` → `Map:loadEntity` in `src/map.lua` (~lines 185–248). New object type = new `src/entities/<type>.lua`; the constructor receives the TMX object (position from `object.x/y`, config from `object.properties`). `typeIgnores` list is at ~line 40.
- Render loop: custom `Map:draw` / `Map:draw2` in `src/map.lua` (~lines 306–331) draws layers in declared order to a fit-to-screen canvas. Layer order = draw order, so `background` must be the first layer in the map. Note STI's own draw (and its parallax support) is bypassed by this override.
- Tile layers with `collision`/`ladder` properties become physics bodies (`src/map.lua` ~76–84) — background entities must NOT create colliders.
- Component pattern: `src/entity.lua` + `src/components/` (sprite, timeline, state_machine…). Sprite supports templated filename sequences, spritesheets, or explicit frame tables; Timeline drives frame index.
- Player proximity query prior art: `Player:checkForUsables` / `queryLadder` in `src/player/player.lua` (~119–195).
- Templates live in `res/templates/*.tx`; existing ones are tile objects (gid from the atlas as placeholder) — new prop templates should reference `res/tilesets/props.tsx` tiles instead so real art shows in Tiled. props.tsx already contains `tree_1.png` as tile 0.

## Gotchas

- **Dual-file rule**: the game loads `res/map/*.lua` (STI Lua export), not the `.tmx`. Every map change must be made in the `.tmx` AND re-exported to `.lua` — hand-edit both consistently if Tiled isn't available (the kill-zones feature did this; see `.scratch/lives-and-kill-zones/` docs while they exist).
- Template-defined properties are resolved into the object by Tiled at export; when hand-editing exports, remember template defaults won't appear unless written into the object.
- Players are spawned/drawn outside the objectgroup entity lists (`src/game_states.lua` ~139–186); confirm background layers draw before players, not just before other layers.
- `Date/randomness in tests`: cloud spawning is randomized — seed or inject randomness for deterministic headless tests (existing harness conventions in `tests/`, run via `test.sh`).
- The hump `Camera` in `src/game_states.lua:133` exists but is unused for drawing — don't wire background motion to it.

## Links

- [PRD](PRD.md) — requirements, stories, acceptance criteria
- [DECISIONS](DECISIONS.md) — grill Q&A and rationale
- Issues: [01](issues/01-gradient-background.md) [02](issues/02-static-props-from-templates.md) [03](issues/03-wind-and-procedural-sway.md) [04](issues/04-proximity-bush-rustle.md) [05](issues/05-cloud-spawner.md) [06](issues/06-frame-animation-and-sandbox-conversion.md)
- No ADRs created — no decision met the hard-to-reverse gate; rationale lives in DECISIONS.md.
