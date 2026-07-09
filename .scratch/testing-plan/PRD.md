# Quick Gameplay Regression Tests

## Problem Statement

Gameplay behavior is changing quickly as movement, physics, animation, menu flow, and rendering are improved. Without fast automated tests, simple regressions can slip in unnoticed: walking may stop selecting the run animation, facing may flip incorrectly, gravity may become too slow again, or collision response may accidentally cancel the wrong velocity axis.

The project currently has no obvious automated test suite. Manual LÖVE smoke tests are useful, but they are too slow and broad to run after every small gameplay change.

## Solution

Add a tiny, dependency-free Lua test runner for fast headless regression tests. The first tests should focus on the highest-value gameplay logic that can be checked quickly without launching a full LÖVE window:

1. Player movement/facing/animation decisions.
2. Bump physics gravity and collision response essentials.

Small testability refactors are allowed where they make the behavior easier to test without pulling in the whole game runtime. The initial suite should be deliberately small: enough to catch the common regressions, not a comprehensive simulation.

## User Stories

1. As a developer, I want to run a quick command after movement changes, so that I know left/right movement still sets velocity, facing, and animation correctly.
2. As a developer, I want a fast test for falling physics, so that gravity does not accidentally become too slow or unbounded again.
3. As a developer, I want a fast test for collision response, so that solid collisions cancel the correct velocity axis without sensors stopping movement.
4. As a developer, I want tests that do not require external Lua packages, so that the project remains easy to set up.
5. As a developer, I want tests that avoid launching a full graphical game where possible, so that they are fast enough to run frequently.
6. As a developer, I want small, focused tests before broad integration tests, so that failures point to a likely cause.
7. As a developer, I want the test harness to be understandable, so that future gameplay tests can be added without learning a large framework.
8. As a developer, I want tests to be compatible with the current global-heavy architecture where necessary, so that test adoption can be incremental.
9. As a developer, I want small refactors to isolate decisions from runtime state, so that behavior can be tested without brittle full-game mocks.
10. As a developer, I want a clear path to later add LÖVE/map smoke tests, so that the fast suite can grow into broader confidence over time.

## Implementation Decisions

- Use a tiny custom Lua test runner with no external dependencies.
- Add a simple test command such as `lua tests/run.lua` or `luajit tests/run.lua` depending on what is available locally.
- Keep tests fast and headless for the first slice.
- Prefer extracting small pure helper modules/functions over mocking the entire LÖVE runtime.
- Start with essentials only:
  - movement input decision -> horizontal velocity, facing, animation name
  - gravity acceleration -> downward velocity increases
  - terminal velocity -> downward velocity clamps
  - collision response -> solid contacts cancel matching velocity axis; cross/sensor contacts do not
- Do not attempt to fully instantiate `Player`, `World`, `Map`, or STI in the initial unit tests unless needed.
- Keep the production code changes minimal and behavior-preserving.
- Future test layers may add LÖVE-hosted integration tests for map/entity loading, but that is out of scope for the first implementation slice.

## Testing Decisions

- Good tests should assert externally meaningful gameplay behavior rather than implementation details.
- First modules/areas to test:
  - player movement/facing decision logic extracted from `src/player/player_states.lua`
  - bump physics gravity/collision math extracted from or made callable within `src/physics/bump/collider.lua`
- Test files should live under a top-level `tests/` directory because this is a custom Lua test harness rather than framework-specific co-located tests.
- Proposed layout:
  - `tests/run.lua` — custom runner and assertion helpers
  - `tests/player_movement_test.lua` — movement/facing/animation essentials
  - `tests/bump_physics_test.lua` — gravity and collision-response essentials
- Tests should not require Slab, STI, assets, or a graphical LÖVE window.
- Tests may set up minimal globals only where unavoidable for requiring legacy modules.
- Each test file should return/register test cases in a simple consistent format.
- The test runner should print concise pass/fail output and exit non-zero on failure.

## Out of Scope

- Full map loading tests.
- Full LÖVE window boot tests.
- Asset existence validation.
- CI wiring, unless it is trivial after the runner exists.
- Replacing the custom runner with Busted or another framework.
- Comprehensive player state machine coverage.
- End-to-end multiplayer/controller testing.
- Visual regression testing.
- Physics backend parity between `bump` and LÖVE/Box2D.

## File Structure (if relevant)

```text
tests/
├── run.lua
├── player_movement_test.lua
└── bump_physics_test.lua
```

Optional production seam modules/functions may be added near the source they support, for example a small player movement decision helper and small bump physics helper functions.

## Acceptance Criteria

- [ ] A dependency-free command runs the fast unit tests from the repository root.
- [ ] The test command exits with status `0` when tests pass.
- [ ] The test command exits non-zero when any test fails.
- [ ] At least one movement test verifies moving right sets right velocity/facing/walk animation.
- [ ] At least one movement test verifies moving left sets left velocity/facing/walk animation.
- [ ] At least one movement test verifies no horizontal input selects idle behavior.
- [ ] At least one physics test verifies gravity increases downward velocity.
- [ ] At least one physics test verifies fall speed clamps at terminal velocity.
- [ ] At least one physics test verifies solid vertical collision cancels vertical velocity.
- [ ] At least one physics test verifies cross/sensor contacts do not cancel velocity.
- [ ] Tests run without launching a LÖVE window.
- [ ] README or AGENTS context documents the test command once implemented.

## References

- `src/player/player_states.lua` — current movement/facing/animation decisions.
- `src/player/player.lua` — player speed, facing, animation state names.
- `src/physics/bump/collider.lua` — gravity, terminal velocity, collision response.
- `AGENTS.md` — project architecture and validation guidance.
