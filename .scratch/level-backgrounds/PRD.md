# Level Backgrounds

## Problem Statement

Level backgrounds are currently plain tile layers (`sky`, `trees` in sandbox) drawn from the tileset atlas. This means backgrounds can only be made of static 32px tiles: no gradients, no motion (drifting clouds, swaying trees), and no player interaction (a bush rustling as the player runs past). Most maps (e.g. ll1) have no background at all because tile-based backgrounds are tedious to author. Level authors need richer backgrounds that are quick to set up in Tiled.

## Solution

A background system authored entirely in the map file via a `background` objectgroup layer, spawned through the existing TMX-object → entity pipeline. Authors get:

- A **gradient** rect object (top colour → bottom colour, with a "cover map" checkbox) drawn behind everything.
- A **cloud spawner** rect object that fills its region with drifting clouds picked from a pool of Tiled templates; clouds wrap around the map edges.
- **Prop** tile objects (tree, bush) placed from Tiled templates backed by the `props` image-collection tileset, so the real art is visible at real size in the editor.
- **Motion** per prop: procedural (sine sway, shake/squash) and/or frame animation, composable.
- **Interaction** via a generic proximity mechanism: a prop can react when a player passes near it (bush rustles).
- A **global wind** value per map (with a code default) scaled by per-object multipliers, driving cloud drift and tree sway together.

Background objects are pure visuals: they never collide with or obstruct the player.

## User Stories

1. As a level author, I want to define a sky gradient in Tiled, so that levels have richer skies than flat tile colours.
2. As a level author, I want a "cover map" checkbox on the gradient, so that I don't have to size the rect exactly to the map.
3. As a level author, I want to place a cloud spawner region, so that the sky populates itself without me placing every cloud.
4. As a level author, I want the spawner to accept a pool of templates, so that I control which cloud variants appear.
5. As a level author, I want clouds to wrap around the map edges, so that the sky never empties out.
6. As a level author, I want to place trees and bushes from templates that show the actual art in the editor, so that I can see roughly how the level will look while editing.
7. As a level author, I want to set one global wind value on the map, so that I can make the whole level calm or stormy without touching every object.
8. As a level author, I want per-object wind/speed multipliers, so that individual props can vary within the global wind.
9. As a level author, I want wind to have a sensible default, so that backgrounds work even if I set nothing on the map.
10. As a level author, I want to give any background prop a `depth` value now, so that parallax works automatically once the future camera rework lands.
11. As a player, I want trees to sway gently in the wind, so that levels feel alive.
12. As a player, I want a bush to rustle when I run past it, so that the world reacts to me.
13. As a player, I want background elements to never block movement or collide with me, so that decoration doesn't affect gameplay.
14. As a level author, I want props to optionally play frame animations (alone or combined with procedural motion), so that richer art can be used when available.
15. As a developer, I want new background object types to follow the existing entity-from-TMX recipe, so that adding one is just a new entity file plus map objects.
16. As a developer, I want a reusable proximity component, so that future entities can react to nearby players without new detection code.
17. As a level author, I want sandbox converted to the new system, so that there is a working reference level to copy from.

## Implementation Decisions

- **Authoring model**: one `background` objectgroup layer per map, placed below all other layers (existing layer-order-equals-draw-order rendering handles depth). All background elements are objects in this layer.
- **Spawning**: background object types ride the existing `Map:loadEntity` pipeline — each type is a new entity module under the entities directory, constructed from the TMX object. No registry edits.
- **Gradient entity** (`type=gradient`): rect object with properties `colorTop` (color), `colorBottom` (color), `coverMap` (bool). When `coverMap` is true the gradient fills the entire map regardless of rect geometry. Rendered as a vertex-coloured mesh/quad. Draws first within the background layer.
- **Cloud spawner entity** (`type=cloud_spawner`): rect object defining the spawn region. Properties: template pool via `file` properties (`spawn1`, `spawn2`, …) pointing at `.tx` templates, `count` (int), optional speed/scale variance, `windScale` multiplier, `depth`. On load it instantiates `count` clouds at randomized positions within the region with randomized template/speed/scale. Clouds drift horizontally with wind and wrap around the map bounds (stable population — no despawn/respawn).
- **Prop entities** (`type=tree`, `type=bush`, generalizable): tile objects from templates backed by the `props` image-collection tileset (so real art shows in the editor). Common properties: `depth`, `windScale`, motion options, optional frame-animation source, optional proximity reaction settings.
- **Motion system**: composable options on a background prop —
  - *Procedural*: parameterized sway (sine skew/rotation, wind-driven) and shake/squash (triggered impulse that decays). Works on single-frame art.
  - *Frame animation*: reuses the existing Sprite + Timeline components when frames are configured.
  - A prop may enable either or both simultaneously.
- **Proximity component**: a new generic component following the existing component pattern. Configured with a radius (and enabled via a property such as `reactToPlayer`), it monitors player distance using the established world-query/player-position patterns and emits enter/exit signals. The bush subscribes and triggers its rustle (shake) on enter.
- **Wind**: map custom property `windX` (signed; direction+strength). Code default applies when absent. Effective motion = global wind × per-object `windScale`. Drives both cloud drift velocity and sway strength.
- **Parallax readiness**: all background elements store a `depth` property (default 1.0 = no parallax). It is persisted and plumbed into the draw path but has no visual effect until the future camera rework multiplies it into the draw offset. No camera changes in this feature.
- **No physics**: background entities create no colliders and never appear in physics queries (except the proximity component's own distance checks, which are read-only).
- **Dual-file rule**: every map change is made in both the Tiled source map and the re-exported Lua map the game loads (existing project convention).

## Testing Decisions

- Tests target external behaviour via the existing headless Lua test harness in `tests/` (run with `test.sh`), not rendering output.
- Good tests for this feature: entities spawn from map objects with correct configuration (gradient colours, coverMap sizing, spawner population count and region bounds); cloud positions wrap correctly at map edges after simulated updates; wind default applies when the map property is absent; global × per-object wind math; proximity component fires enter/exit at the right distances; bush rustle state triggers on player pass; background entities register no physics colliders.
- Modules tested: the new background entity modules, the proximity component, and the motion helpers.
- Prior art: the lives-and-kill-zones tests and existing `tests/` suites are the template for map-driven entity tests.
- This is a Lua project — follow the existing `tests/` naming and layout conventions rather than the TS/JS naming rules.

## Out of Scope

- Camera/auto-zoom rework and any actual parallax rendering (only the `depth` data is stored).
- Backgrounds for ll1 or any map other than sandbox.
- Real production art — placeholder cloud and bush PNGs are created in-repo; `tree_1.png` is reused.
- Continuous spawn/despawn cloud systems, weather (rain/snow), day/night cycles.
- Foreground/overlay decoration layers (in front of the player).
- Editor tooling beyond standard Tiled templates/tilesets.

## File Structure (if relevant)

- New entity modules in the entities directory (gradient, cloud spawner, tree, bush — or a shared prop module).
- New proximity component in the components directory.
- Placeholder art under the image resources directory; new tiles added to the `props` image-collection tileset; new `.tx` templates alongside the existing ones.
- Sandbox map updated (both Tiled source and Lua export): `background` objectgroup added; old `sky`/`trees` tile layers removed at the end.

## Acceptance Criteria

- [ ] Sandbox renders a top-to-bottom sky gradient defined by a gradient object with `coverMap=true`.
- [ ] A cloud spawner in sandbox populates its region with clouds from its template pool; clouds drift with the wind and wrap at map edges.
- [ ] A tree placed from a template sways procedurally, scaled by global wind × its `windScale`.
- [ ] A bush rustles (shake/squash) when a player runs past it, driven by the generic proximity component.
- [ ] Props can optionally play frame animations, alone or combined with procedural motion.
- [ ] With no `windX` map property, a sensible default wind applies.
- [ ] Background objects never collide with or obstruct players.
- [ ] All background elements accept a `depth` property that is stored and plumbed (visually inert for now).
- [ ] Sandbox's old `sky`/`trees` tile layers are removed; the map looks at least as good as before.
- [ ] Placing any background element in Tiled requires only dragging a template (or drawing a rect) and setting properties — no code changes.
- [ ] Headless tests cover spawning, wrapping, wind defaults/scaling, proximity triggering, and the no-collider guarantee.

## References

- Project glossary: `CONTEXT.md` (new terms added: background prop, cloud spawner, gradient object, wind, depth, proximity component).
- Decision log: `DECISIONS.md` in this directory.
- Prior feature docs (recipe for TMX-driven features): `.scratch/lives-and-kill-zones/`.
