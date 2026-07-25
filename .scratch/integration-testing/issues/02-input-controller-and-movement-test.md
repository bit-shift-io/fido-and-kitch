Status: pending

# Input emulation (FakeInput) + query helpers + movement integration test

## What to build

A contributor can now write a test that holds a movement key for a player across many frames — via keyboard or a simulated joystick — and assert their position changed, using small query helpers instead of reaching into raw entity internals.

Concretely:
- `tests/integration/support/fake_input.lua`: a `FakeInput` controller over the `love_mock` keyboard/joystick state.
  - Keyboard: `press(key)` / `release(key)`.
  - Joystick: assignable per player index; setters for axes (`setAxes(hor, vert)`) and button state (`setButtonDown(1, bool)`), backing `love.joystick.getJoysticks()[index]:getAxes()` / `:isDown(1)`.
  - Helper wrappers built on the primitive: `holdFor(controller, action, seconds, frameStepper)` (press, step N frames at 1/60, release) and `runUntil(frameStepper, predicate, maxFrames)` (step until a condition is true or a frame budget is exhausted, failing the test if exhausted).
- `tests/integration/support/queries.lua`: small helpers — `findEntityByType(map, type)`, and accessors for a player's position, facing, and inventory count, built on the existing entity/component APIs (no new production code).
- `tests/integration/movement_test.lua` using the `flat_ground` fixture from issue 01: drive player 1 right via keyboard for a fixed hold, assert position advanced and facing is `'right'`; release and assert position stops changing over subsequent frames. Repeat the same scenario via the fake joystick's horizontal axis to prove both input paths work. Include a second-player (P2 keyboard scheme) variant to catch input cross-talk between players.

## Files to create/modify

- tests/integration/support/fake_input.lua
- tests/integration/support/queries.lua
- tests/integration/movement_test.lua

## Test approach

Assert observable gameplay state only (position, facing, inventory) via the query helpers — never reach into `love_mock` internals from the test file itself. Cover: keyboard-driven P1 movement, joystick-driven P1 movement, keyboard-driven P2 movement (independent control scheme), and that releasing input stops the player.

## Acceptance criteria

- [ ] `FakeInput` supports keyboard press/release independently of joystick axis/button state.
- [ ] `FakeInput` supports a fake joystick with `getAxes()`/`isDown(1)` assignable per player index.
- [ ] `holdFor` and `runUntil` helpers exist and are used by the movement test.
- [ ] Query helpers (`findEntityByType`, player position/facing/inventory accessors) exist and are used instead of raw internals in the test.
- [ ] Movement test passes for keyboard P1, joystick P1, and keyboard P2 scenarios.

## Blocked by

01-harness-foundation
