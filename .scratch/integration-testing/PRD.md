# Gameplay Integration Testing

## Problem Statement

The project's existing `tests/` suite only exercises pure logic and small isolated modules (movement decisions, bump-physics overlap queries) without ever loading a real map, running the player FSM, or advancing the game loop. There is no way to catch regressions that only show up when a whole level is loaded and a player actually moves through it — e.g. a switch that stops wiring up to its target, a fixture map that fails to load, or player movement breaking once real components (Sprite, Collider, Inventory) are all attached. Contributors currently only catch these by manually launching the game.

## Solution

Add a second category of tests — integration tests — that instantiate the real `Game`/`InGameState`/`Map`/`Player` stack against small dedicated Tiled fixture maps, drive player input the way a human would (holding/releasing keyboard keys or joystick axes across many simulated frames), and assert on the resulting game state. These run outside the real LÖVE runtime by providing a minimal Lua mock of the `love.*` API surface the loaded modules actually touch, so tests stay headless and fast like today's unit tests, while covering true end-to-end behaviour. A separate command runs them, so the existing fast unit-test loop (`./test.sh`) is unaffected.

## User Stories

1. As a contributor, I want to write a test that loads a small fixture map, holds the "right" key for a player, and asserts their position advanced, so that I can catch movement regressions without manually launching the game.
2. As a contributor, I want to simulate two players with independent control schemes (P1 keyboard/joystick 1, P2 keyboard/joystick 2) in the same test, so that co-op-specific bugs (e.g. one player's input leaking into the other's) are catchable.
3. As a contributor, I want to simulate a joystick's analog axes and a button, so that gamepad-driven movement and "use" actions are covered, not just keyboard.
4. As a contributor, I want to assert on gameplay state (player position, inventory contents, whether a switch/target fired, lives remaining) via small helper query functions, so that tests read clearly and don't duplicate lookup logic.
5. As a contributor, I want a shared library of minimal fixture maps (e.g. a flat ground room, a room with one pressure switch), so multiple tests can reuse the same map instead of each authoring their own.
6. As a contributor, I want an integration test that loads every real map under `res/map/` and asserts it loads without error, so that a broken Tiled export or a bad entity type reference is caught automatically instead of only surfacing at manual playtest time.
7. As a contributor, I want integration tests to run via a distinct command from the fast unit tests, so that the fast feedback loop (`./test.sh`) stays instant and integration tests can be run deliberately (locally or as a separate CI step).
8. As a contributor, I want the simulation stepped at a fixed timestep (1/60s) rather than wall-clock time, so that "hold this key for 2 seconds" is deterministic and reproducible across machines.
9. As a maintainer, I want the `love.*` mock's surface to be limited to what the loaded modules actually call (keyboard, joystick, graphics no-ops, filesystem map loading) rather than a full LÖVE reimplementation, so it stays small and maintainable.
10. As a contributor, I want fixture maps authored the same way real levels are (Tiled `.tmx` source, exported to `.lua` via the normal pipeline), so fixtures stay editable in Tiled and don't drift from the real map format.

## Implementation Decisions

- A new `love` mock module provides the subset of the LÖVE API that loading a map, its entities, and stepping the game loop actually touch: `love.keyboard.isDown`, `love.joystick.getJoysticks` (returning zero or more fake joysticks with `getAxes`/`isDown`), `love.filesystem.load` (loads the exported map `.lua` the way STI expects), and no-op/stub `love.graphics` calls (`newImage`, `newQuad`, `draw`, `setColor`, `push`/`pop`/`translate`/`scale`/`origin`, `getWidth`/`getHeight`) sufficient for STI map loading and `Sprite` component construction to complete without error. Fake images expose `getWidth`/`getHeight`/`getDimensions`/`setFilter`.
- Integration tests only exercise the `bump` physics backend (the project default per `conf.lua`); the `love`/Box2D physics backend's extra `love.physics` surface is out of scope.
- A test-facing `FakeInput` controller wraps the mock's keyboard/joystick state: `press(key)` / `release(key)` for keyboard, and axis/button setters for a fake joystick assigned to a given player index. Helper wrappers (`holdFor`, `runUntil`) build on top of this primitive for common patterns (hold a direction for N seconds; step frames until a predicate is true or a frame budget is exhausted).
- A frame-stepping helper advances the game at a fixed timestep of 1/60s per step, calling `Game:update(dt)` (and optionally `keypressed`/`joystickpressed` for one-shot actions like "use") the requested number of times.
- Small test-only query helpers (e.g. `findEntityByType(map, type)`, player/inventory/position accessors) reduce lookup boilerplate across integration tests; these live alongside the other test support modules, not in production `src/`.
- Integration tests start directly in `InGameState` via `startGame({map=...})`, bypassing `MenuState`/Slab UI navigation, mirroring the existing `map=` launch-arg pattern in `src/main.lua`. Menu/UI-driven integration tests are out of scope for this feature (see Out of Scope).
- Fixture maps are authored as real Tiled maps: a `.tmx` source plus its exported `.lua`, following the same pipeline as `res/map/`, checked into a shared fixtures location so multiple tests can load the same map.
- A new "load every real map" smoke test iterates the exported `.lua` files under `res/map/`, loads each through the same `Map`/`Game` stack used by other integration tests, and asserts loading completes without error.
- Integration tests run via a new, separate command from `./test.sh`, using its own runner/file list so the existing fast unit-test loop is untouched.

## Testing Decisions

- Integration tests are themselves the tests-under-design here; "what makes a good test" is: it drives the game via the same input path a human uses (keyboard/joystick state read each frame by `Player:isDown`), advances real frames, and asserts on observable gameplay state — never reaching into private internals to shortcut the behaviour it's meant to verify.
- Modules exercised: `src.game`, `src.game_states` (`InGameState`), `src.map`, `src.player.player` (+ states), relevant `src/components/*`, and the `bump` physics backend — all as real code, not mocked; only the LÖVE engine boundary is mocked.
- Prior art: `tests/kill_zone_test.lua` already exercises real `World`/`Collider` behaviour without a LÖVE dependency by avoiding any draw call — the new work extends this idea to the full playable stack, where drawing paths can't be avoided at load time and need mocking.
- File naming: this project's existing convention is `tests/*_test.lua` (not `.test.ts`/`.test.js`, since this is a Lua/LÖVE project, not a JS one). Integration tests adopt the same suffix convention: `tests/integration/*_test.lua`.
- File location: `tests/integration/` for integration test files, `tests/integration/fixtures/` for shared fixture maps (`.tmx` + exported `.lua`), `tests/integration/support/` for the love mock, frame-stepper, `FakeInput`, and query helper modules.

## Out of Scope

- Driving `MenuState`/Slab menu UI navigation via simulated input (mouse/keyboard through the menu) — tests start directly in `InGameState`.
- The `love`/Box2D physics backend (`t.physics = 'love'`) — only `bump` is covered.
- Visual/pixel-level assertions (screenshots, rendering correctness) — `love.graphics` calls are no-ops; only gameplay state is asserted.
- A full LÖVE-headless-binary test runner — deferred; the mock approach is the initial delivery (see DECISIONS.md for the hybrid rationale).
- Broad mechanic coverage beyond the first slice (ladders, enemies, pushables/boulders, cage objective) — this feature delivers the harness plus movement + one mechanic (pressure switch) + the all-maps smoke test; further mechanic-specific integration tests are follow-up work using the same harness.
- CI wiring (e.g. adding the new command to a GitHub Actions workflow) — not addressed here unless the user asks for it explicitly during implementation.

## File Structure

```
tests/
  integration/
    support/
      love_mock.lua        -- minimal love.* stub surface
      frame_stepper.lua     -- fixed-dt update loop helper
      fake_input.lua         -- FakeInput controller + holdFor/runUntil helpers
      queries.lua             -- findEntityByType, player/inventory accessors, etc.
    fixtures/
      flat_ground.tmx / .lua
      pressure_switch.tmx / .lua
    movement_test.lua
    pressure_switch_test.lua
    all_maps_load_test.lua
    run.lua                    -- integration test runner (mirrors tests/run.lua)
test-integration.sh             -- new top-level command, mirrors test.sh
```

## Acceptance Criteria

- [ ] A `love` mock exists covering keyboard, joystick, filesystem map loading, and enough `love.graphics` no-ops for a real fixture map + entities to load without error.
- [ ] A fixed-timestep (1/60s) frame-stepping helper exists and is used by all integration tests.
- [ ] A `FakeInput` controller supports pressing/releasing keyboard keys and setting fake joystick axes/buttons, independently per player index.
- [ ] At least one shared fixture map (flat ground) is authored in Tiled and loads through the real `Map`/STI pipeline.
- [ ] An integration test drives a player right via keyboard input across multiple frames and asserts their position advanced and stopped changing after the key is released.
- [ ] An integration test drives a player onto a pressure switch fixture map and asserts the switch's target fired.
- [ ] An integration test loads every exported map under `res/map/` and asserts each loads without error.
- [ ] A new command (separate from `./test.sh`) runs the integration suite; `./test.sh` itself is unmodified in scope and stays exactly as fast as before.

## References

- Existing fast-test conventions: `tests/README.md`, `tests/run.lua`, `tests/kill_zone_test.lua`.
- `CONTEXT.md` glossary: `Fast gameplay regression test`, `Testability seam`.
- `AGENTS.md`: physics backend default (`bump`), map/entity conventions.
