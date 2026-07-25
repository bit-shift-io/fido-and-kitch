Status: pending

# Harness foundation: love mock, frame stepper, first fixture map, integration runner

## What to build

The foundational infrastructure that every later integration test builds on, proven end-to-end by one trivial passing test. After this issue:

- A contributor can author a Tiled fixture map, load it through the real `Game`/`InGameState`/`Map` stack outside LÖVE, step the simulation forward at a fixed 1/60s timestep, and see it complete without error.
- Running `./test-integration.sh` executes the integration suite (currently just this one smoke test) separately from `./test.sh`.

Concretely:
- A `love` mock (`tests/integration/support/love_mock.lua`) providing: `love.keyboard.isDown` (backed by a settable key-state table), `love.joystick.getJoysticks` (returns an empty table by default), `love.filesystem.load` (loads an exported map `.lua` file the way STI expects — verify this against a real exported map during implementation, per the assumption flagged in DECISIONS.md), and no-op/stub `love.graphics` calls sufficient for STI + `Sprite` construction to complete: `newImage` (returning a fake image with `setFilter`, `getWidth`, `getHeight`, `getDimensions`), `newQuad`, `draw`, `setColor`, `push`, `pop`, `translate`, `scale`, `origin`, `getWidth`, `getHeight`.
- A frame-stepping helper (`tests/integration/support/frame_stepper.lua`) that calls `Game:update(1/60)` a given number of times.
- One minimal Tiled fixture map (`tests/integration/fixtures/flat_ground.tmx` + exported `.lua`): an empty flat room with a spawn point for at least one player, no special mechanics.
- A new `tests/integration/run.lua` runner mirroring `tests/run.lua`'s `test()`/`assert*` pattern and file-list/failure-reporting behaviour, plus a new top-level `test-integration.sh` mirroring `test.sh`.
- One smoke test (`tests/integration/harness_smoke_test.lua`) that starts a `Game`, jumps to `InGameState:startGame({map='tests/integration/fixtures/flat_ground.lua'})`, steps a handful of frames via the frame stepper, and asserts it completes without error and a player entity exists.

## Files to create/modify

- tests/integration/support/love_mock.lua
- tests/integration/support/frame_stepper.lua
- tests/integration/fixtures/flat_ground.tmx
- tests/integration/fixtures/flat_ground.lua
- tests/integration/run.lua
- tests/integration/harness_smoke_test.lua
- test-integration.sh

## Test approach

The smoke test itself is the verification: load `flat_ground` through the real stack, step ~10 frames, assert no error was thrown and that `InGameState`'s player list is non-empty. Manually confirm `./test-integration.sh` runs only the integration suite and `./test.sh` behaviour/timing is unchanged.

## Acceptance criteria

- [ ] `./test-integration.sh` exists, runs the integration test file list, and exits non-zero on failure (mirroring `test.sh`'s contract).
- [ ] `flat_ground` fixture map loads through the real `Map`/STI pipeline via the `love` mock with no errors.
- [ ] The frame stepper advances `Game:update` at a fixed 1/60s dt for a requested frame count.
- [ ] `./test.sh` is unmodified and unaffected.

## Blocked by

None — can start immediately.
