# Door Entity

## Problem Statement

Levels have no way to gate a passage behind a switch or pressure plate. The
`switch` and `pressure_switch` entities already know how to drive a remote
target through a `target` object-reference and a duck-typed `:switch(switch,
user)` call — `ladder` is the only entity that currently implements that
contract, growing itself when switched on. There's no entity that represents
a plain blocking obstacle: something that stands in the player's way until a
switch says otherwise. The `sandbox` map already has a switch (object id 44)
whose `target` points at the exit door, which has no `:switch()` handler —
so today it visibly toggles but drives nothing.

## Solution

A `door` entity: a player- and pushable-blocking obstacle that starts closed
and implements `:switch(switch, user)`, reading the caller's `state` directly
('on' → open, 'off' → close) rather than toggling independently. Because it
just reacts to whatever `:switch()` call arrives last, it works unmodified
whether the trigger is a lever switch (edge-triggered on each use) or a
pressure switch (momentary or latching) — no door-side knowledge of which
kind of switch is driving it, and nothing stops several switches each
pointing their own `target` at the same door.

Opening and closing plays a reversible timeline animation, the same model
`drawbridge` and `exit_door` already use for their open/close animation. In
the map editor the door is authored as a single 1×1 tile object (matching
every other interactive prop); in-game its sprite renders as a 3×3 tile box
centred on that tile, reusing the drawbridge's `spriteBoxDimensions` bleed
pattern, so a future animation can extend visually into neighbouring tiles
without needing a wider footprint in Tiled. Collision stays a single tile's
width-equivalent (a narrow solid column is enough to block bump's AABB
resolution) but is deliberately kept taller than the tile itself, following
`createStaticPhysicsBodyBoundary`'s pattern of extending a blocking collider
past the exact bounds of what it's guarding, so it doesn't sit flush with the
walking surface in a way that fails to block horizontal movement (a documented
gotcha that has bitten this codebase before).

As a demonstration, the sandbox map's existing switch (object id 44) gets
re-targeted from the exit door to a newly placed door object near the switch,
so the previously-inert wiring drives something visible.

## User Stories

1. As a level designer, I want to place a door object in Tiled that looks
   like a door, so I can visually recognise it while laying out a map.
2. As a level designer, I want to point a switch's `target` at a door, so
   flipping the switch opens it.
3. As a level designer, I want to point a pressure switch's `target` at a
   door, so stepping on the plate opens it and leaving releases it (or, if
   the plate is latching, it stays open once triggered).
4. As a player, I want a closed door to physically block my path, so I can't
   walk or fall through it.
5. As a player, I want a closed door to block pushable crates the same way a
   wall would, so I can't shove a box through it.
6. As a player, I want the door to still block me while it's swinging shut,
   so I can't sneak through mid-close.
7. As a player, I want to be free to walk through once the door has fully
   finished opening, not just once it starts opening.
8. As a player, I want a door that's fully open and then triggered closed to
   block me again as soon as it starts closing.
9. As a level designer, I want a door left untouched by any switch to default
   to closed, so an unwired door still gates the passage it sits in rather
   than silently doing nothing.
10. As a level designer, I want two different switches to each be able to
    target the same door independently, so I can gate one passage from
    either side without the door needing special configuration.
11. As a player exploring the sandbox map, I want the switch that currently
    does nothing to open a nearby door, so the level demonstrates the
    switch → door wiring working end to end.

## Implementation Decisions

- New entity at `src/entities/door.lua`, single file (per ADR 0003/0005 and
  the drawbridge/pressure_switch precedent — no multi-file split unless a
  pure-helper module genuinely can't be constructed headless, and
  `tests/support/headless_bootstrap.lua` already makes that possible).
- State: `'closed' | 'opening' | 'open' | 'closing'`, starting at `'closed'`.
  No per-instance `startOpen`-style override — closed is the only default.
- `Door:switch(switch, user)` reads `switch.state` ('on'/'off') and computes
  the next state via a pure transition function (mirroring
  `Drawbridge._internal.nextStateOnHeldChange`), handling the drawbridge's
  same interrupt case: flipping direction mid-transition reverses the
  in-flight animation from its current frame (`Sprite:reverseFromCurrent`)
  rather than snapping.
- Solid whenever state is not `'open'` (closed, opening, and closing all
  block) — the inverse of `Drawbridge.isDeckSolid` (which is solid whenever
  *not* `'closed'`). Passable only once the state machine reaches `'open'`
  (i.e. only after the opening animation's `finish` callback fires), not the
  instant `'opening'` begins.
- No per-frame occupancy/proximity polling — unlike `drawbridge` and
  `pressure_switch`, the door has no `update()`-driven trigger of its own; it
  only changes state in response to an externally-called `:switch()`.
- Blocks the same categories as the drawbridge's own gap-hazard logic
  considers a legitimate occupant: players and pushable props
  (`entity.isPushable`) — i.e. a normal solid wall-like collider, not a
  sensor with manual filtering.
- Collider: rectangle, static body, sensor toggled by `isDeckSolid`-style
  helper (`sensor = state == 'open'`). Width: roughly 1/4 of the tile's own
  width (matching the drawbridge trigger's proportions), widened to 1/2 if a
  quarter proves unreliable in practice — width doesn't need to span the
  full tile since any solid rectangle in the path fully blocks horizontal
  movement under bump. Height: taller than the tile itself, following
  `createStaticPhysicsBodyBoundary`'s pattern of extending a blocking
  collider beyond the exact bounds of what it guards rather than sitting it
  exactly flush with the floor.
- Sprite: reuses the drawbridge's `spriteBoxDimensions` pattern —
  `object.width * 3, object.height * 3`, centred on the object's own
  position — purely visual bleed; never used as a hint for collision.
  Animation is a reversible timeline (`playForward`/`playReverse`/
  `reverseFromCurrent`), matching drawbridge/exit_door.
- Editor representation: a `gid`-based Tiled object (bottom-anchored via
  `Rect.centreOfMapObject`, like `switch`/`key`/`coin`), 1 tile (32×32) in
  size, so it's visually recognisable in Tiled. Reuses the existing
  `entity_door.png` art already present in `res/tilesets/props.tsx` (tile id
  5 / gid 6) — currently only referenced by the `exit_door` template
  (`exit.tx`); nothing prevents a second object `type` (`door`) referencing
  the same tileset tile for its editor icon, since the tile is purely a
  Tiled-side preview and doesn't affect which entity class gets constructed
  (that's driven by the object's `type` attribute, resolved through
  `entity_factory.lua`).
- New `res/templates/door.tx` template, `type="door"`, no `target` property
  by default (each map instance sets its own, or several instances of switch
  each set their own `target` to the same door — the door doesn't declare a
  reverse link).
- Sound: `Sound` component with `open`/`close` clips, following the
  drawbridge/pressure_switch precedent of referencing wav paths that don't
  exist yet (`Sound:play` warns and skips headlessly and at runtime) — no
  new asset files are in scope for this feature.
- Sandbox integration: `res/map/sandbox.tmx` gets a new `door` object placed
  near the existing switch (object id 44), and the switch's `target`
  property is overridden on the instance to point at the new door object's
  id instead of inheriting the template default (`target=43`, the exit
  door). Exact tile position is a demo placement, not a real level-design
  choice — anywhere near the switch that visibly blocks a short passage is
  sufficient.

## Testing Decisions

- Pure decision helpers (state transition function, solidity-from-state
  predicate) exposed via a `Door._internal` white-box seam, mirroring
  `Drawbridge._internal` / `PressureSwitch._internal` (ADR 0005) — fast,
  construction-free unit tests in `tests/unit/door_test.lua` covering every
  state × input combination, especially the mid-transition interrupt cases
  (opening→closing and closing→opening) and the "solid unless fully open"
  boundary (opening is solid, open is not).
- Entity-level tests (construction, real `Sprite`/`Collider`/`Sound` wiring,
  actually calling `:switch()` and observing collider solidity flip) via
  `tests/support/headless_bootstrap.lua`, following the drawbridge and
  pressure_switch test files as prior art.
- Integration coverage for the `target` + `:switch()` wiring itself
  (switch → door, and pressure_switch → door) alongside the existing
  switch/ladder integration tests, if such a test file already exists for
  that mechanism — otherwise a new integration test constructing a switch
  and a door from real Tiled-object-shaped data and asserting the door opens
  and closes.
- No test asserts anything about the sandbox map integration beyond "the
  file parses and the two objects reference each other correctly" — visual
  demo correctness in `sandbox.tmx` is verified by playing the map, not by
  an automated test.

## Out of Scope

- Real open/close sound assets (referenced paths only, following the
  pressure_switch precedent).
- Any door variant that is directly `Usable` by the player (opened by
  pressing a use-key) — this door only ever changes state via `:switch()`.
- A generalised many-to-many "wiring" system beyond the existing single
  `target` property per switch — multiple switches may each point at one
  door, but a door has no concept of requiring all of its drivers to agree.
- Directional crossing semantics (drawbridge-style `crossingDirection`) —
  the door blocks or permits passage from both sides identically.
- Any change to `exit_door`, `ladder`, `switch`, or `pressure_switch` beyond
  the sandbox map's `target` property re-pointing.
- New tileset art or a new tileset tile — reuses the existing
  `entity_door.png` tile already declared in `props.tsx`.

## File Structure

```
src/entities/door.lua              # new entity
res/templates/door.tx              # new Tiled object template (type="door")
res/map/sandbox.tmx                # modified: new door object + switch's target re-pointed
tests/unit/door_test.lua           # new
tests/integration/...              # new or extended, wherever switch/ladder wiring is covered
```

## Acceptance Criteria

- [ ] A `door` object can be placed in Tiled as a 1×1 tile using
      `entity_door.png` art, and shows up correctly in the editor.
- [ ] In-game, the door's sprite renders as a 3×3 tile box centred on its
      placed tile.
- [ ] The door starts closed and blocks both the player and pushable props.
- [ ] Calling `:switch()` with `state == 'on'` opens the door (plays the
      opening animation); the door remains solid until the animation
      finishes.
- [ ] Once open, the door is fully passable by players and pushables.
- [ ] Calling `:switch()` with `state == 'off'` closes the door and it
      becomes solid again the instant closing begins.
- [ ] Flipping the request mid-animation reverses the current animation in
      place rather than snapping or restarting.
- [ ] A lever `switch` and a `pressure_switch` (both momentary and latching)
      can each independently drive a door via the existing `target` +
      `:switch()` convention with no door-side special-casing.
- [ ] In `sandbox.tmx`, the existing switch (object id 44) is re-targeted to
      a newly placed door object, and flipping the switch in-game visibly
      opens/closes that door.

## References

- `.scratch/door/DECISIONS.md`
- `src/entities/drawbridge.lua` — reversible timeline, sprite bleed
  (`spriteBoxDimensions`), interrupt-mid-transition handling.
- `src/entities/pressure_switch.lua` — `target` + `:switch()` convention,
  momentary vs. latching.
- `src/entities/ladder.lua` — the only existing `:switch()` implementer.
- `src/map/collision_builder.lua` — `createStaticPhysicsBodyBoundary`, the
  pattern for extending a blocking collider past the exact bounds it guards.
- `docs/adr/0003-multi-file-entity-directories.md`,
  `docs/adr/0005-headless-entity-testing.md`.
- `CONTEXT.md` — new "Door" glossary entry.
