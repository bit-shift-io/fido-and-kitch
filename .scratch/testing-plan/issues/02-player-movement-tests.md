Status: pending

# Test player movement, facing, and animation decisions

## What to build

Add a small testable seam for player movement decisions and cover the most important behaviors with fast headless tests.

After this slice, tests should catch regressions where moving left/right stops setting the correct velocity, facing direction, or animation selection.

## Files to create/modify

- `src/player/player_states.lua`
- Optional new helper near player code, e.g. `src/player/player_movement.lua`
- `tests/player_movement_test.lua`
- `tests/run.lua` if adding the test file list there

## Test approach

Use simple tables/fakes instead of real `Player`, `Collider`, `StateMachine`, or LÖVE objects where possible.

Essential tests:

- Moving right chooses positive horizontal velocity, right facing, and walk/run animation.
- Moving left chooses negative horizontal velocity, left facing, and walk/run animation.
- No horizontal input chooses zero horizontal velocity and idle animation.

The tests should verify behavior, not the exact implementation of the state machine.

## Acceptance criteria

- [ ] Movement decision logic can be tested without launching LÖVE.
- [ ] Moving right test passes.
- [ ] Moving left test passes.
- [ ] Idle/no horizontal input test passes.
- [ ] Existing runtime movement behavior is preserved.
- [ ] Tests run through the custom runner.

## Blocked by

Issue 01 — custom test runner.
