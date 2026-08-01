Status: pending

# Door entity: state machine, animation, collision, editor template

## What to build

A new `door` entity (`src/entities/door.lua`) that:

- Starts `closed` on construction.
- Implements `:switch(switch, user)`, reading `switch.state` ('on'/'off') and
  transitioning toward `open`/`closed` via `opening`/`closing` states, using
  a reversible-timeline animation (`playForward`/`playReverse`/
  `reverseFromCurrent`) exactly like `drawbridge`. Flipping the requested
  direction mid-animation reverses in place rather than snapping.
- Is solid (blocks players and pushables) whenever its state is not `open`
  (closed, opening, and closing all block); becomes passable only once the
  opening animation's `finish` callback lands the state on `open`.
- Renders its sprite as a 3×3 tile box centred on its object tile
  (`spriteBoxDimensions`-style, reusing the drawbridge's pattern), while its
  collision footprint stays roughly 1/4 tile wide (bump to 1/2 if unreliable)
  and taller than one tile, following `createStaticPhysicsBodyBoundary`'s
  pattern of extending a blocking collider past the exact bounds of what it
  guards.
- Is authored in Tiled as a 1×1 `gid`-based object (bottom-anchored), via a
  new `res/templates/door.tx` template with `type="door"`, reusing the
  existing `entity_door.png` tile already declared in
  `res/tilesets/props.tsx` (tile id 5 / gid 6).
- Has a `Sound` component with `open`/`close` clips referencing wav paths
  that don't yet exist (matches the `pressure_switch` precedent — no new
  audio assets in scope).
- Has no `Usable` component — it is only ever driven by an external
  `:switch()` call.

This slice is demoable and verifiable entirely on its own (headless unit and
entity tests, plus manual placement in any existing Tiled map), independent
of the sandbox integration in issue 02.

## Files to create/modify

- src/entities/door.lua
- res/templates/door.tx
- tests/unit/door_test.lua
- tests/support/headless_bootstrap.lua (only if it needs a small extension to construct a `door`; check first — drawbridge/pressure_switch already establish the pattern)

## Test approach

- Pure decision-helper unit tests (`Door._internal`, mirroring
  `Drawbridge._internal`/`PressureSwitch._internal`): a state-transition
  function covering every `(state, requestedOpen)` combination, especially
  the two mid-transition interrupt cases (opening→closing,
  closing→opening), and a solidity-from-state predicate asserting solid for
  `closed`/`opening`/`closing` and passable only for `open`.
- Entity-level tests via `tests/support/headless_bootstrap.lua`: construct a
  real `Door`, call `:switch({state='on'}, nil)` and `:switch({state='off'},
  nil)`, and assert the collider's solidity and the sprite's animation
  direction change as expected, including the interrupt case on a real
  constructed entity.
- No test needs a real switch/pressure_switch instance for this slice —
  that cross-entity wiring is covered in issue 02 (or wherever the
  switch/ladder integration tests already live, if extending them is more
  natural than adding a new file).

## Acceptance criteria

- [ ] `Door` starts `closed` and is solid to both players and pushables.
- [ ] `:switch(switch, user)` with `switch.state == 'on'` opens the door;
      it remains solid through `opening` and becomes passable only on
      reaching `open`.
- [ ] `:switch(switch, user)` with `switch.state == 'off'` closes the door;
      it becomes solid the instant `closing` begins.
- [ ] Flipping direction mid-animation reverses the current animation in
      place (no snap, no restart from the opposite end).
- [ ] The door's sprite draws at 3× the object's tile dimensions, centred on
      the object; the collider stays roughly 1/4 tile wide and taller than
      one tile.
- [ ] A `door` object placed in Tiled via `door.tx` shows the door art as a
      1×1 tile.
- [ ] `Door._internal`'s pure helpers are unit-tested for every
      state/input combination described above.

## Blocked by

None — can start immediately.
