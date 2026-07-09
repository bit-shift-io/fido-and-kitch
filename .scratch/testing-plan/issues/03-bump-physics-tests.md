Status: pending

# Test bump gravity and collision essentials

## What to build

Add a small testable seam for the core bump physics math and cover the most important falling/collision behaviors with fast headless tests.

After this slice, tests should catch regressions where gravity becomes too weak, fall speed is no longer clamped, or collision handling cancels the wrong movement.

## Files to create/modify

- `src/physics/bump/collider.lua`
- Optional new helper near bump physics code, e.g. `src/physics/bump/motion.lua`
- `tests/bump_physics_test.lua`
- `tests/run.lua` if adding the test file list there

## Test approach

Prefer testing pure functions for velocity updates rather than instantiating a full bump world.

Essential tests:

- Gravity increases downward velocity for dynamic bodies.
- Fall speed clamps at the configured maximum.
- Solid vertical collision cancels vertical velocity when moving into the surface.
- Cross/sensor contact does not cancel velocity.

Keep values simple and assert game invariants rather than exact real-world physics.

## Acceptance criteria

- [ ] Gravity behavior can be tested without launching LÖVE.
- [ ] Terminal velocity clamp test passes.
- [ ] Solid vertical collision cancellation test passes.
- [ ] Cross/sensor non-cancellation test passes.
- [ ] Existing runtime falling/collision behavior is preserved.
- [ ] Tests run through the custom runner.

## Blocked by

Issue 01 — custom test runner.
