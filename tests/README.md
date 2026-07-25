# Tests

The suite is split into three tiers, each with its own command:

```sh
./test-unit.sh          # fast headless Lua tests (no LÖVE window, no map loading)
./test-integration.sh   # headless real-stack tests (maps loaded through a love.* mock)
./test-e2e.sh           # headed tests: real LÖVE, real window, real rendering
./test-all.sh           # runs all three in sequence and reports each tier's outcome
```

Every command is dependency-free and exits non-zero if any test fails. Pass a specific test file as an argument to run just that one, e.g.:

```sh
./test-unit.sh tests/unit/runner_smoke_test.lua
```

`./test-all.sh` skips the e2e tier automatically when a `CI` environment variable is set (no display or real LÖVE binary exists in CI), printing an explicit skip message rather than silently omitting it.

## Tiers

- **`tests/unit/`** — fast gameplay regression tests. Pure logic/math, no map loading, no LÖVE surface at all.
- **`tests/integration/`** — loads a real map through the actual `Game`/`InGameState`/`Map`/`Player` stack, driving simulated input across stepped frames, outside LÖVE via a minimal `love.*` mock. No real rendering; frame capture is unavailable here.
- **`tests/e2e/`** — the same kind of scripted, deterministic scenario as the integration tier, but launched as a real LÖVE process with a real window and real rendering. Watchable, and the only tier where frame capture works. A test belongs to exactly one tier — there is no running the same file both headless and headed. `all_maps_screenshot_test.lua` is the e2e counterpart of the integration tier's `all_maps_load_test.lua`: it loads every real map under `res/map/` and captures a screenshot of each, so a broken map or a visual regression across any shipped level is a screenshot away rather than a manual launch.

## Shared infrastructure

- **`tests/support/`** — test-support modules shared across tiers: game bootstrap (`game_harness.lua`), frame stepping (`frame_stepper.lua`), fake input (`fake_input.lua`), gameplay query helpers (`queries.lua`), the headless `love.*` mock (`love_mock.lua`), and the frame capture API (`capture.lua`).
- **`tests/fixtures/`** — shared fixture maps (small, dedicated Tiled maps authored for tests, never shipped).
- **`tests/screenshots/`** — capture output from the e2e tier, gitignored. Organised per test so a run's output is easy to find and clear.

## Writing an e2e test

An e2e test file looks exactly like an integration test — same `test()`/`assert*` surface, same `GameHarness`/`FrameStepper`/`FakeInput`/`Queries` helpers — with two differences:

```lua
local game = GameHarness.startGame('res/map/my_fixture.lua', {real = true})  -- {real = true}, not the mock
local controller = FakeInput.new()  -- still shims love.keyboard/love.joystick, now in front of real LÖVE's own
```

`{real = true}` skips installing the headless `love.*` mock and boots against the real `love` global the engine already provided; `tests/support/game_harness.lua` then calls `_G.E2E_ON_GAME_STARTED(game)` (set by `tests/e2e/run.lua`) so the runner knows which game object to draw and capture from every frame. Everything else — `FrameStepper.step`, `holdFor`, `runUntil`, the query helpers — is unchanged from the integration tier.

Run a single e2e file directly against real LÖVE while iterating:

```sh
love . e2e=tests/e2e/my_scenario_test.lua
```

`./test-e2e.sh` does this once per file under `tests/e2e/`, discovering the LÖVE binary the same way `run.sh` does (`bin/love.AppImage` if present, else `love` on PATH), and forwards two flags as LÖVE launch arguments:

```sh
./test-e2e.sh --paced                        # one simulated frame per drawn frame, matches real time, actually watchable
./test-e2e.sh --filmstrip                    # capture every 10th simulated frame (default interval)
./test-e2e.sh --filmstrip=5                  # capture every 5th simulated frame instead
```

Both are off unless asked for: default is fast-as-possible with no filmstrip.

## Frame capture (e2e tier only)

Scenario code can request a named capture at any point in a headed test via `Capture.capture(name)` (see `tests/support/capture.lua`), writing a real rendered image to `tests/screenshots/<test-file>/<name>.png`. A failing assertion automatically captures the frame at the point of failure (named `FAILURE_<test name>.png`) and the failure output names the file. An optional filmstrip, off by default, captures every Nth frame when enabled via the `./test-e2e.sh` flags above.

Calling the capture function from the unit or integration tier raises an explicit error naming the e2e tier as the requirement — it is never a silent no-op.

Captures are debugging artifacts, not visual-regression baselines: they are gitignored and never diffed against a committed reference image.

## Physics gotchas that surface only under real rendering

The integration tier's headless `love.*` mock never calls `love.graphics`, so these only bite in the e2e tier — worth knowing before writing a new headed scenario that stands an entity on, or walks a player into, something other than plain map terrain:

- **A solid collider owned by an entity is invisible to "am I on the ground?" checks by default.** `Player:queryOnGround()` and `GroundSupport.isFullySupported()` both only recognise a collider as ground when it has no owning entity (`collider.entity == nil`) — correct for plain Tiled terrain, but a custom entity's own solid collider (e.g. a drawbridge deck) needs an explicit `collider.walkable = true` opt-in (mirrored through query results by `src/physics/bump/world.lua`'s `queryRectangleArea`) or a player standing on it gets stuck in `FallState` forever, unable to walk, despite being fully physically supported.
- **A solid rect flush with the ground's top edge does not act as a wall.** Two static solid rectangles of the same height that both start at the walking surface (e.g. a "closed door" collider shaped exactly like a floor tile) resolve as a walkable step under this project's simple AABB collision (`lib/bump`), not a horizontal block — a player can walk straight through at normal standing height. A collider meant to block horizontal entry needs to be taller than the walking surface (see the map's own boundary walls in `Map:createStaticPhysicsBodyBoundary`, or the drawbridge's barrier collider in `src/entities/drawbridge.lua`), not just "solid".

Both of the above were found by `tests/e2e/drawbridge_test.lua` — real physics under real rendering surfaced them; the headless integration/unit tiers could not.
