# Pushable Props (Push Box, Boulder, Pressure Switch)

## Problem Statement

The game has no way for players to change the level's physical layout. Every gap, ledge and switch is fixed, so puzzles can only ask the player to route *around* the world, never to *reshape* it. There's no "move this object to solve that problem" mechanic — the raw material for spatial/environmental puzzles is missing.

## Solution

Introduce **pushable props** the player can shove around the level, plus a weight-activated **pressure switch** they can drive:

- A **push box** slides in the direction the player walks into it. Push it off a ledge and it drops straight into the gap, snapping to fill a hole so the player can walk across — turning "there's a pit here" into a solvable puzzle.
- A **boulder** works the same to start, but once shoved it keeps rolling on its own until it hits a wall, another prop, a player, or a gap it falls into.
- A **pressure switch** activates while a qualifying weight (a player or a pushable) is resting on it, driving a target entity through the same mechanism the existing lever `switch` uses. Combined, these let designers build "put the box on the plate to open the door" puzzles.

All three are placed in Tiled and built from shared components (composition), with placeholder quad rendering until real art exists.

## User Stories

1. As a player, I want to walk into a box and have it slide in my direction, so that I can reposition it.
2. As a player, I want the box to stop the instant I stop walking or turn away, so that pushing feels controlled and deliberate.
3. As a player, I want to push a box off a ledge into a pit and have it drop straight in and fill the gap, so that I can then walk across.
4. As a player, I want to stand and walk on top of a box or boulder as if it were solid ground, so that props double as platforms.
5. As a player, I want a box with something resting on top of it to be un-pushable, so that stacked props behave predictably.
6. As a player, I want a box I'm standing on to be un-pushable by default, so that I don't accidentally slide myself off (with a per-prop opt-in for co-op push puzzles).
7. As a player, I want a box that runs into a wall or another prop to simply stop, so that props can't be forced through the world or each other.
8. As a player, I want to shove a boulder once and watch it roll on its own until it hits something or falls, so that momentum-based puzzles are possible.
9. As a player, I want a boulder to stop harmlessly when it reaches a wall, prop, or player, and be pushable again if there's room, so that it stays predictable.
10. As a player, I want a prop that falls into water to sink to the bottom of the level and rest there, so that dropping a prop in water is a real (if lossy) outcome.
11. As a player, I want to push a box onto a pressure plate and have it activate the plate's target (e.g. open a cage/door), so that props solve switch puzzles.
12. As a player, I want to stand on a pressure plate myself to activate it, so that I can hold a mechanism open.
13. As a player, I want a momentary pressure plate to deactivate when the last weight leaves, so that the mechanism follows the weight.
14. As a designer, I want a latching option on a pressure plate so it stays on once triggered, so that I can build one-shot triggers.
15. As a designer, I want to place push boxes, boulders and pressure switches from the Tiled template palette, so that authoring is drag-and-drop.
16. As a designer, I want a pressure switch to drive a target entity through the same `target` + `:switch()` mechanism the lever switch uses, so that it works with existing switchable entities (cages, doors, etc.).
17. As a designer, I want all props and switch states to reset to their spawn state on level restart, so that puzzles start clean.
18. As a player, I want props to stay exactly where they are when I die and respawn (only I reset), so that a single death doesn't undo my progress mid-level.

## Implementation Decisions

- **New entities** (`Class{__includes = Entity}`, one Tiled `type` each; separate entities, shared components):
  - `push_box` — dynamic collider + `Pushable` component in slide mode + placeholder quad.
  - `boulder` — dynamic collider + `Pushable` component in roll mode + placeholder quad.
  - `pressure_switch` — sensor collider + weight-detection + `target`/`:switch()` drive (mirrors the lever `switch`).
- **`Pushable` component** — shared behaviour for props the player can push: horizontal slide at player walk speed while pushed (slide mode) or momentum roll after an initial push (roll mode); "can this be pushed right now?" gating (grounded pusher, direction held, nothing pushable on top, no player on top unless opted in, not currently airborne); support-under-centre-x check driving fall-and-snap into holes; blocked by walls and other pushables.
- **Support / fall / snap model** (deliberately not free physics teetering): support is decided by what solid ground sits under the prop's **centre-x**. While the centre is over solid ground the prop rests at whatever x it was left at (no forced alignment). Once the centre passes over an unsupported tile, the prop snaps its x to that tile's centre (within a small tolerance) and falls straight down; it is un-pushable while airborne and pushable again once landed. See ADR 0001.
- **Pressure switch activation** — a qualifying weight (player or pushable) counts as "on" the plate when its centre-x aligns with the plate tile's centre within tolerance ("substantially on it") while overlapping it. Activated while ≥1 qualifying weight is on; deactivates when the last leaves. Momentary (default) re-drives the target on both activate and deactivate; latching drives once on first activation and never releases. Box **snap-to-plate** happens on push-release (not mid-push, so it never fights the player): when the player stops pushing and the box centre-x is within tolerance of the plate, the box snaps to the plate tile centre.
- **Reuse** — `Collider` (dynamic for props, sensor for the plate), gravity/fall via the existing `Collider:worldUpdate`/`Motion` path (zero horizontal velocity already falls straight down), ground/support probing patterned on `GroundSupport`, and the lever switch's `target`/`:switch()` drive.
- **Tiled templates** — one `.tx` per new type in `res/templates/`, placed on an objectgroup layer. Per-prop custom properties (e.g. `allowPushWhenStoodOn`) and per-switch properties (`target`, `latching`) read via `object.properties.*` in `init`.
- **Reset** — a per-prop snapshot of spawn state (position, and for the switch its off state) captured at load, re-applied on level restart. Death/respawn does not touch props.

## Testing Decisions

- Good tests here assert **external decisions and geometry**, not internal wiring: given a world state, does the prop decide to move / fall / snap / activate correctly? Follow the project's existing headless "fast gameplay regression test" pattern (`tests/run.lua`, e.g. `tests/ground_support_test.lua`, `tests/player_movement_test.lua`, `tests/bump_physics_test.lua`) rather than launching LÖVE.
- Extract pure decision helpers so they're testable without the full runtime (mirrors the project's existing testability seams, e.g. `GroundSupport`):
  - support-under-centre-x → rest vs fall, and the snap-target x for a given prop position and tile grid.
  - "can push now?" gating given pusher grounded/direction and on-top occupancy.
  - boulder roll continuation + stop conditions.
  - pressure-switch activation: centre-x alignment test, momentary vs latching state transitions, multi-weight last-one-leaves.
- Modules exercised: the `Pushable` component's decision helpers, the shared support/snap helper, and the pressure switch's activation logic.
- File naming/location: headless Lua tests as `tests/*_test.lua` registered in `tests/run.lua`, matching existing project convention (the repo does not use the `.unit.test.ts` convention; match the project's Lua test style).

## Out of Scope

- **Buoyancy / floats-vs-sinks flag.** Deferred. Props that fall into water sink to the bottom map border and rest there (water is cosmetic + a kill-zone sensor the prop crosses without dying). No per-prop float flag.
- **Sound effects and real art/animation.** Placeholder quads only.
- **Props interacting with any entity other than players and other pushables.** No pushing/blocking of coins, birds, keys, etc.
- **Props damaging players.** Boulders and boxes never hurt or crush the player; they stop harmlessly.
- **Any editor beyond Tiled.** No custom in-repo editor UI; placement is Tiled templates + custom properties.
- **Chaining/trains of props.** Pushing a prop into another prop just stops; you cannot push a line of two props at once.
- **Grid-locked (Sokoban) movement.** Props slide continuously and rest at arbitrary x; alignment happens only on the two forcing events (fall, plate).

## File Structure

```
src/
  components/
    pushable.lua          # new: shared push/slide/roll/fall-snap behaviour
  entities/
    push_box.lua          # new
    boulder.lua           # new
    pressure_switch.lua   # new
  (support/snap helper)   # new small module or function, patterned on src/player/ground_support.lua
res/
  templates/
    push_box.tx           # new
    boulder.tx            # new
    pressure_switch.tx    # new
  map/
    sandbox.(tmx|lua)     # add example props + a plate-driven target for manual demo
tests/
  pushable_*_test.lua     # new headless decision tests, registered in tests/run.lua
docs/adr/
  0001-pushable-motion-and-snap-model.md
```

## Acceptance Criteria

- [ ] A `push_box` placed in Tiled loads, falls to rest on ground, blocks the player, and can be stood/walked on.
- [ ] Walking a grounded player into a box slides it at walk speed; it stops the instant the player stops or turns away.
- [ ] A box pushed over a one-tile gap snaps to the gap-tile centre and drops straight in, then is walkable across; it is pushable again once landed.
- [ ] A box is un-pushable while another pushable rests on it; un-pushable while a player stands on it unless `allowPushWhenStoodOn` is set.
- [ ] A box/boulder stops on hitting a wall or another pushable; pushing a prop into another prop never moves both.
- [ ] A `boulder` shoved once keeps rolling at walk speed until it hits a wall/prop/player or falls into a gap (snapping like a box), then can be pushed again if there's room; it never harms the player.
- [ ] A prop that falls into water sinks to and rests on the bottom map border.
- [ ] A `pressure_switch` activates while a player or a pushable is substantially on it (centre-x within tolerance) and drives its `target` via `:switch()`.
- [ ] Momentary (default) deactivates and re-drives the target when the last weight leaves; latching stays on after first activation.
- [ ] A box pushed onto a plate snaps to the plate tile centre on push-release and activates it; the player can push it back off.
- [ ] On level restart, all props return to spawn positions and switch states reset; on player death/respawn, props are untouched.
- [ ] New decision logic is covered by headless tests registered in `tests/run.lua` and they pass.

## References

- Codebase anchors: entity base `src/entity.lua`; example entities `src/entities/kill_zone.lua`, `src/entities/switch.lua`, `src/entities/cage.lua`, `src/entities/ladder.lua`; components `src/components/`; player probing `src/player/player.lua`, `src/player/ground_support.lua`; physics/gravity `src/physics/bump/collider.lua`, `src/physics/bump/motion.lua`, `src/physics/bump/world.lua`; map/entity load `src/map.lua`; templates `res/templates/`; maps `res/map/sandbox.*`; tests `tests/run.lua`.
- `docs/adr/0001-pushable-motion-and-snap-model.md` — the deterministic support/fall/snap model.
- `.scratch/pushable-props/DECISIONS.md` — full grill rationale.
- Glossary: `CONTEXT.md` (Pushable, Push box, Boulder, Pressure switch, Snap alignment).
