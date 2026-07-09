# Quick Gameplay Regression Tests — Handoff

## Summary

Add a tiny, dependency-free Lua test harness focused on fast gameplay regression tests. The first implementation should not try to test the whole game or launch a LÖVE window. Instead, it should create a minimal `tests/run.lua` runner and a few essential tests for player movement/facing/animation decisions and bump physics gravity/collision behavior.

Small production refactors are allowed where they make behavior testable without brittle full-game mocks. Keep these seams narrow and close to the code they support. The goal is to create a foundation that can be run frequently during gameplay iteration.

## Suggested Implementation Order

1. **Issue 01 — Add the custom test runner**
   - Establish `tests/run.lua` and basic assertion/output/exit behavior.
   - This is the foundation for all following issues.

2. **Issue 02 — Extract and test player movement decisions**
   - Add a small pure movement decision seam.
   - Cover moving left, moving right, and idle/no movement behavior.
   - Keep the production state code using this helper so tests and runtime share behavior.

3. **Issue 03 — Extract and test bump physics essentials**
   - Add helper functions or module-level functions for gravity/clamping/collision velocity cancellation.
   - Cover gravity acceleration, terminal velocity, solid vertical collision, and cross/sensor non-cancellation.

4. **Optional follow-up after these issues**
   - Document the test command in `README.md` and `AGENTS.md` if not already done during issue 01.
   - Add inventory/usable tests as the next gameplay area.
   - Add slower LÖVE/map smoke tests later if desired.

## Planning Docs

- PRD: `.scratch/testing-plan/PRD.md`
- Decisions: `.scratch/testing-plan/DECISIONS.md`
- Issues: `.scratch/testing-plan/issues/`

## Implementation Notes

- Keep tests runnable from repository root.
- Prefer `lua tests/run.lua`; if LuaJIT-specific behavior is needed, document `luajit tests/run.lua` as an alternative.
- Avoid requiring `src/main.lua` in unit tests because it initializes globals and LÖVE callbacks.
- Avoid loading maps, STI, Slab, assets, or LÖVE graphics in the first suite.
- If a source file currently needs globals just to be required, consider extracting a small pure module rather than mocking a large runtime.
- Keep failure output concise and readable.
- Ensure the runner exits non-zero on failure so it can be used in CI later.

## Gotchas

- Current project architecture intentionally uses globals; do not attempt a broad dependency-injection refactor as part of this feature.
- Player movement currently lives in state objects; test seams should preserve runtime behavior.
- Bump physics code uses a simple platformer-style approximation, not real-world physics. Tests should assert desired game feel invariants, not physical realism.
- The LÖVE/Box2D backend exists but is not the active target for the first physics tests.
