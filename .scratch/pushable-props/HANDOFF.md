# Handoff — Pushable Props

## Summary
Add three cooperating props to the LÖVE/Lua game: a **push box** (slides while a grounded player walks into it), a **boulder** (same start, then keeps rolling on momentum until it hits something or falls), and a **pressure switch** (weight-activated plate that drives a target entity). Boxes and boulders fall straight down and **snap to fill one-tile holes** so the player can walk across, and can be shoved onto pressure plates to trigger mechanisms. Everything is placed in Tiled and built by composition — separate entities (`push_box`, `boulder`, `pressure_switch`) sharing a `Pushable` component and a small support/snap helper. Placeholder quad rendering; no art, sound, or buoyancy in this feature.

The defining design choice is the **deterministic support-and-snap model** (ADR 0001): props rest at arbitrary x and only align to a tile on two forcing events — falling into a gap, and seating on a plate (on push-release). This is a deliberate departure from free physics teetering so hole-filling and plate-seating are reliable.

## Suggested implementation order
Strictly sequential — each slice builds on the last:

1. **01 — Push box static blocker.** Get the entity rendering, falling, blocking, and standable. Establishes the entity + Tiled template + placeholder-draw plumbing.
2. **02 — Pushable component (slide).** Add the shared component and player-driven push with all the gating. First interactive slice.
3. **03 — Fall-and-snap into holes.** The core puzzle mechanic + ADR 0001 model. Introduces the support/snap helper other slices reuse.
4. **04 — Boulder.** Cheap once 02/03 exist — a second entity + a roll mode on the component.
5. **05 — Pressure switch.** Reuses the switch target-drive and the snap helper; needs a landed/pushable box to test against.
6. **06 — Level-restart reset.** Wire up (or verify) reset; do last, once props and switches exist.

Slices 04 and 05 are independent of each other and could be built in either order after 03.

## Key references
- **PRD:** `.scratch/pushable-props/PRD.md`
- **Decisions/rationale:** `.scratch/pushable-props/DECISIONS.md`
- **ADR 0001** (support/fall/snap model): `docs/adr/0001-pushable-motion-and-snap-model.md`
- **Glossary** (Pushable, Push box, Boulder, Pressure switch, Snap alignment): `CONTEXT.md`

## Implementer notes & gotchas
- **Gravity is free.** A dynamic `Collider` with zero horizontal velocity already falls straight down via `Collider:worldUpdate` → `Motion` (`src/physics/bump/collider.lua`, `motion.lua`). Don't reimplement falling — just don't add horizontal velocity during a fall, and drive the snap/rest decision on top.
- **Solid map ground has no `.entity`.** Static map colliders (from the `collision` objectgroup, `src/map.lua:createStaticPhysicsBodies`) carry no `.entity`, which is exactly how `GroundSupport`/player probes tell solid ground from entities. Reuse that to implement support-under-centre-x. Tile size is `map.tilewidth`/`map.tileheight` (32).
- **Copy the query pattern, not raw bump.** Player surroundings use `World:queryBounds`/`queryRectangleArea` with an `.entity` attached (`src/physics/bump/world.lua`, `src/player/player.lua` queryOnGround/queryKillZone). Mirror this for "is there a prop/player on top?", "what's beside the prop?", and "is the box over a plate?".
- **Pressure switch = lever switch's twin.** Reuse the `target` property + `target.entity:switch(self, user)` drive from `src/entities/switch.lua`; `src/entities/cage.lua` is a ready switchable target for the demo. The difference is the *trigger* (weight/presence, polled each update) not the *effect*.
- **Snap timing differs by event.** Hole snap fires at the moment of falling (mid-push is fine). Plate snap fires on **push-release** only, so it never fights the player's input. Keep these two paths distinct.
- **Water needs no special-casing.** Water is cosmetic tiles + a `kill_zone` sensor (`deathType="water"`); sensors are crossed by dynamic bodies, so a sinking prop just keeps falling to the bottom map boundary. Don't add buoyancy — it's explicitly deferred.
- **Locate the restart path before slice 06.** Confirm whether a level restart re-instantiates entities from the map (reset is then automatic and the work is verifying death does *not* reset) or reuses live entities (needs `resetToSpawn()`). Check `src/game_states.lua` (InGameState:load, onPlayerDied) and `src/game.lua` map loading. Death/respawn must leave props untouched either way.
- **Tests are headless.** Extract pure decision helpers and register `tests/*_test.lua` in `tests/run.lua`; run with `./test.sh`. Match existing style (`tests/ground_support_test.lua`, `tests/player_movement_test.lua`, `tests/bump_physics_test.lua`). Manual/visual verification via `./run.sh` (add `drawphysics` to see colliders/queries); place demo props in `sandbox`.
- **Tiled workflow.** Author objects in `.tmx`, add a `.tx` template per type in `res/templates/`, and export the map to `.lua` (both files coexist; the game loads only the `.lua`). Custom properties (`allowPushWhenStoodOn`, `target`, `latching`) read via `object.properties.*` in `init`.
- **Placeholder colours (dealer's choice, easily changed):** box brown, boulder grey, plate colour-shift on active. All props 32×32.
