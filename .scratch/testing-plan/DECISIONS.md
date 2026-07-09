# Quick Gameplay Regression Tests — Decisions

### Q1: What is the main goal for adding tests right now?

**Decision:** Focus first on catching regressions in gameplay logic.

- **Why:** Recent changes have touched movement, falling physics, animation, and map/menu transitions. These are easy to regress and painful to verify manually after every edit.
- **Implication:** The first suite should test behavior such as movement direction, animation selection, gravity, and collision response instead of broad packaging or visual checks.
- **Alternatives considered:** Startup/runtime smoke tests, CI confidence, and refactor support. These remain useful later, but gameplay logic has the highest immediate value.

### Q2: Should tests be quick?

**Decision:** Yes. The first suite should be fast and headless.

- **Why:** Tests are most valuable if they are cheap enough to run frequently during gameplay iteration.
- **Implication:** Avoid launching a full LÖVE window or loading maps/assets in the first slice.
- **Alternatives considered:** LÖVE-hosted integration tests. Rejected for the first slice because they are slower and more setup-heavy.

### Q3: Are small testability refactors allowed?

**Decision:** Yes. Small refactors are allowed where they isolate gameplay decisions.

- **Why:** The existing code relies on globals and runtime objects, which makes direct unit tests brittle. Small pure helper seams will make tests simpler and more durable.
- **Implication:** Implementation can extract movement/facing decisions and bump physics math into small callable functions while preserving current behavior.
- **Alternatives considered:** No refactors. Rejected because it would likely require brittle mocks of `Player`, `StateMachine`, `Collider`, globals, and LÖVE runtime state.

### Q4: What test runner/dependency style should be used?

**Decision:** Use a tiny custom test runner with no external dependencies.

- **Why:** The project should stay lightweight and easy to run from a fresh clone.
- **Implication:** Create a simple `tests/run.lua` with minimal assertion helpers and test registration/loading.
- **Alternatives considered:** Busted and LÖVE-hosted tests. Busted is more full-featured but adds a dependency. LÖVE-hosted tests are useful later but slower for the initial goal.

### Q5: Which gameplay areas should be first?

**Decision:** Start with a few essentials for player movement/facing/animation decisions and bump physics gravity/collision behavior.

- **Why:** These are the most recently adjusted gameplay systems and likely to regress during continued tuning.
- **Implication:** The initial tests should be intentionally small rather than comprehensive.
- **Alternatives considered:** Inventory, pickup/usable interactions, doors/cages/objectives. These are good next candidates after the first test harness exists.

## Key Assumptions

- A Lua interpreter such as `lua` or `luajit` will be available for running headless tests.
- Tests should run from the repository root.
- The first suite can avoid requiring `love` by extracting pure logic where necessary.
- The bump backend is the active physics backend and the first physics target.
- The goal is regression confidence, not perfect physics simulation fidelity.

## Trade-offs

- **Custom runner vs framework:** A custom runner is simpler and dependency-free, but less feature-rich than Busted.
- **Pure helper seams vs full object tests:** Helper seams are easier to test quickly, but they require small production refactors.
- **Unit tests first vs integration tests first:** Unit tests are faster and more focused, but they will not catch map/entity wiring problems until later phases.

## Updated CONTEXT.md Entries

- **Fast gameplay regression test** — a headless Lua test that checks gameplay decisions or math quickly without launching a graphical LÖVE game.
- **Testability seam** — a small extracted function/module that makes existing behavior testable without broad runtime mocks.
