# Decisions: Gameplay Integration Testing

### Q1: How should integration tests get a `love` API to run against?
**Decision:** Build a minimal Lua-only mock of the `love.*` surface the game actually touches, run via plain `lua`/`luajit` like today's tests — with an explicit intent that the input-emulation layer (`FakeInput`, frame stepper) is designed so it could later point at a real headless LÖVE process if the mock proves insufficient.
- **Why:** Keeps integration tests fast and CI-friendly with no new runtime dependency (no headless LÖVE setup), consistent with the project's existing "dependency-free, fast" testing philosophy (`tests/README.md`). The user explicitly wants the option open for real LÖVE later if the mock's fidelity becomes a limiter.
- **Implication:** The mock's surface is scoped to what's actually called during map/entity load and the update loop (see Q5), not a full LÖVE reimplementation. If a future mechanic needs LÖVE behaviour the mock can't cheaply fake (e.g. real Box2D physics), that's a signal to revisit the "real LÖVE" branch of this decision for that slice specifically.
- **Alternatives considered:** Real LÖVE headless run — rejected for now as slower and needing a display-less LÖVE setup/new runner; pure mock forever (no escape hatch) — rejected because it locks out higher-fidelity tests later.

### Q2: Shape of the input-emulation API
**Decision:** Both a low-level imperative `FakeInput` controller (`press`/`release` for keys, axis/button setters for joystick) and small helper wrappers (`holdFor`, `runUntil`) built on top.
- **Why:** An imperative controller reads like a script of a human playing and supports reactive tests ("press use once near the switch"), which a pure declarative frame-timeline can't express cleanly. Helpers remove boilerplate for the common "hold a direction for N seconds" case without losing the low-level primitive for anything more conditional.
- **Implication:** Test authors write `controller:press('right')` then step frames, using `holdFor`/`runUntil` when the pattern is simple and dropping to raw `press`/`release`/frame-stepping when it isn't.
- **Alternatives considered:** Declarative timeline only — rejected, too rigid for conditional/reactive scenarios. Imperative only, no helpers — rejected, too much repeated boilerplate across tests.

### Q3: Where do integration tests start the game from?
**Decision:** Tests jump straight into `InGameState:startGame({map=...})`, skipping `MenuState`/Slab menu navigation. Menu-driven tests are acknowledged as also wanted eventually but are out of scope for this feature's issue breakdown.
- **Why:** Matches the existing `map=` launch-arg pattern already used for manual dev testing (`src/main.lua`); decouples gameplay-logic tests from the unrelated Slab menu UI, which is more brittle to drive via simulated input.
- **Implication:** A future feature (not this one) would need its own input-emulation work for Slab-driven menu navigation, which has different concerns (mouse position, UI widget state) than gameplay input.
- **Alternatives considered:** Driving the full FSM from `MenuState` for every test — rejected as the default because it couples every gameplay test to menu UI internals; the user confirmed some future tests will want menu coverage specifically, so this is deferred rather than ruled out.

### Q4: What maps do integration tests load?
**Decision:** Dedicated shared minimal fixture maps (authored in Tiled, `.tmx` + exported `.lua`) for targeted mechanic tests, plus a separate smoke test that loads every real map under `res/map/`.
- **Why:** Minimal fixtures stay stable and won't break when a designer reworks a real level in Tiled; the all-maps smoke test still gives blanket protection against a broken export or bad entity reference in real content.
- **Implication:** Fixture maps live under `tests/integration/fixtures/`, are built with the real Tiled editor (not hand-written Lua tables), and can be shared across multiple tests where their layout fits (e.g. `flat_ground` reused by several movement-style tests).
- **Alternatives considered:** Hand-written minimal Lua map tables — rejected as prone to drifting from what STI/Tiled actually export.

### Q5: `love.graphics`/STI mock surface investigation
**Decision:** Scope the mock to exactly what map loading and entity construction call, based on reading the actual code paths: `love.graphics.newImage` (+ `setFilter`, `getWidth`/`getHeight`/`getDimensions` on the returned fake image), `love.graphics.newQuad`, `love.graphics.draw`/`setColor`/`push`/`pop`/`translate`/`scale`/`origin` as no-ops, `love.filesystem.load` (for STI's `love.filesystem.load(map)()` map-loading call), `love.keyboard.isDown`, `love.joystick.getJoysticks`.
- **Why:** Confirmed by reading `lib/sti/init.lua`, `lib/sti/utils.lua`, `src/components/sprite.lua`, and `src/player/player.lua`: STI's texture atlas packer (`lib/sti/atlas.lua`, which would need `love.graphics.newCanvas`/`getSystemLimits`) is never called anywhere in `src/` — confirmed via grep for `:atlas(`/`.atlas(` with zero hits — so it's excluded from the mock. Confirmed the Box2D plugin path (`map:box2d_init`, which needs `love.physics.*`) only runs when `world.type == 'love'` (`src/map.lua`); the project's default and this feature's scope is the `bump` backend (`conf.lua`), so `love.physics` is excluded too.
- **Implication:** The mock stays small and grounded in what's actually exercised; if a later mechanic pulls in an unmocked LÖVE call, extend the mock at that point rather than pre-building unused surface.
- **Alternatives considered:** Mocking the full `love.graphics`/`love.physics` API defensively up front — rejected as unnecessary maintenance burden for calls nothing in this codebase makes.

### Q6: Joystick/gamepad emulation scope
**Decision:** Include basic joystick emulation now (fake joystick with `getAxes()` and `isDown(1)`), alongside keyboard.
- **Why:** User explicitly wants gamepad-driven movement/use covered by this feature, not deferred — `Player:isDown` branches on `love.joystick.getJoysticks()[self.index]` before falling back to keyboard, so without a fake joystick option that whole branch is untested.
- **Implication:** `FakeInput` needs a joystick mode (settable axes + button state) as well as a keyboard mode, assignable per player index; `love.joystick.getJoysticks()` in the mock returns a per-index table of fake joysticks (possibly empty, so keyboard-only tests still fall through correctly).
- **Alternatives considered:** Keyboard-only for this feature — rejected per user's explicit choice.

### Q7: Test organization and run command
**Decision:** A separate `tests/integration/` folder with its own runner (mirroring `tests/run.lua`) and a new top-level command (e.g. `test-integration.sh`), distinct from `./test.sh`.
- **Why:** Integration tests are heavier (real map loads, many simulated frames) than the existing instant unit tests; keeping them behind a separate command preserves the fast feedback loop `./test.sh` currently provides and lets integration tests be run deliberately (locally, or as a distinct CI step later).
- **Implication:** `./test.sh` and `tests/run.lua` are unmodified by this feature. The new runner follows the same dependency-free `test()`/`assert*` pattern already established, to avoid two incompatible testing DSLs.
- **Alternatives considered:** Folding integration tests into the existing `./test.sh` default file list — rejected because it would slow down the fast loop every contributor relies on for quick iteration.

### Q8: Simulation timestep
**Decision:** Fixed dt = 1/60s per simulated frame.
- **Why:** Deterministic and reproducible across machines/CI; matches the common target framerate, so "hold right for 2 seconds" is simply 120 stepped frames — easy to reason about and write.
- **Implication:** The frame-stepper helper hardcodes 1/60 rather than exposing a configurable dt parameter.
- **Alternatives considered:** Per-test configurable dt — rejected as unnecessary complexity; no identified test needs a different timestep, and a fixed value keeps all integration tests directly comparable.

### Q9: Initial scenario scope
**Decision:** First slice covers harness infra + a basic movement test + one interactive mechanic (pressure switch, chosen as a self-contained mechanic with a clear pass/fail signal: does the target fire) + the all-real-maps load smoke test. Ladders, enemies, and pushables/boulders are explicitly deferred as follow-up work using the same harness.
- **Why:** Keeps the first delivery tight and reviewable; the harness (mock, controller, fixture pipeline, query helpers) is the expensive/foundational part, and proving it works end-to-end on one representative mechanic is enough to validate the approach before investing in broader coverage.
- **Implication:** The issue breakdown has four issues, not a dozen; adding ladder/enemy/pushable integration tests later is straightforward re-use of this same harness and doesn't require new infra design.
- **Alternatives considered:** Broader first pass (ladders, enemies, pushables included) — rejected by the user in favor of the tighter scope.

## Key Assumptions

- The `bump` physics backend remains the project default for the duration of this feature (confirmed in `conf.lua`).
- STI's atlas-packing plugin and the Box2D plugin path are genuinely unused in this codebase (confirmed via grep), so their LÖVE calls don't need mocking. If either becomes used later, the mock will need extending at that point.
- The exported map `.lua` format loaded via `love.filesystem.load` behaves like a plain Lua chunk loader (`loadfile`-equivalent) when given a real filesystem path outside the LÖVE runtime — this is a load-bearing assumption for `love.filesystem.load`'s mock implementation and should be verified against a real exported map file during implementation of the first issue.

## CONTEXT.md updates

New glossary entries added (see `docs/CONTEXT.md` / `CONTEXT.md`):
- **Integration test** — distinguishes from the existing "Fast gameplay regression test" entry.
- **Fixture map** — the shared minimal Tiled maps used by integration tests.
