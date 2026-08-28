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

## AI Agent Control Layer

The test infrastructure doubles as a programmable control layer for AI agents. Any agent can drive the game by requiring the test support modules:

```lua
local GameHarness = require('tests.support.game_harness')
local FakeInput = require('tests.support.fake_input').FakeInput
local FrameStepper = require('tests.support.frame_stepper')
local holdFor = require('tests.support.fake_input').holdFor
local Capture = require('tests.support.capture')  -- e2e tier only

-- Start game (headless integration: omit {real=true}; headed e2e: include it)
local game = GameHarness.startGame('res/map/sandbox.tmj', {real = true})
local controller = FakeInput.new()

-- Keyboard input (P1 uses arrow keys + rshift; P2 uses WASD + Q)
controller:press('right')
holdFor(game, controller, 'right', 2)  -- hold for 2 seconds
controller:release('right')

-- Gamepad input (P1 = index 1, P2 = index 2)
local joy = controller:assignJoystick(1)
joy:setAxes(1, 0)      -- right stick X axis
joy:setButtonDown(1, true)  -- button 1 (use)

-- Window control (via controller:window() in e2e tier; direct love.window in integration)
local win = controller:window()
win:maximize()
win:minimize()
win:restore()
win:setFullscreen(true, 'desktop')   -- fullscreen
win:setFullscreen(false)             -- windowed
win:setMode(1024, 768)               -- resize window

-- Direct love.window calls (also work in e2e)
love.window.setFullscreen(true, 'desktop')
love.window.maximize()
love.window.minimize()
love.window.restore()
love.window.setMode(1024, 768)

-- Step simulation at fixed 1/60s timestep
FrameStepper.step(game, 60)  -- advance 60 frames

-- Frame capture (e2e tier only)
local path = Capture.capture('my_screenshot')  -- writes to tests/screenshots/<test>/my_screenshot.png
```

**Tiers:**
| Tier | Command | Window | Rendering | Frame Capture |
|------|---------|--------|-----------|---------------|
| Integration | `./test-integration.sh` | Mock (no window) | No | No |
| E2E | `./test-e2e.sh` / `love . e2e=...` | Real | Yes | Yes |

E2E flags: `--paced` (1 sim frame = 1 real frame, watchable), `--filmstrip` / `--filmstrip=N` (capture every N frames).

Key files:
- `tests/support/fake_input.lua` — `FakeInput` API (`press`, `release`, `assignJoystick`, `holdFor`, `runUntil`, `window()`)
- `tests/support/game_harness.lua` — boots real game stack
- `tests/support/frame_stepper.lua` — fixed-timestep frame advancement
- `tests/support/capture.lua` — frame capture (e2e only)
- `tests/integration/key_test.lua` — minimal working example

No special prompts needed — the test infrastructure *is* the control layer.

## Writing an e2e test

An e2e test file looks exactly like an integration test — same `test()`/`assert*` surface, same `GameHarness`/`FrameStepper`/`FakeInput`/`Queries` helpers — with two differences:

```lua
local game = GameHarness.startGame('res/map/my_fixture.tmj', {real = true})  -- {real = true}, not the mock
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

- **`collider.walkable` is a capability flag, not a standing guarantee — it must be paired with the collider's current `sensor` state.** `Player:queryOnGround()` and `GroundSupport.hasGroundAt()` recognise a collider as ground when it has no owning entity (`collider.entity == nil`), *or* when it's a custom entity's own collider explicitly opted in via `collider.walkable = true` (e.g. a drawbridge deck) *and* it is not currently a sensor. Both conditions matter: skip the `walkable` opt-in on an entity-owned solid collider and a player standing on it gets stuck in `FallState` forever, unable to walk, despite being physically supported; skip the "not currently a sensor" check (the actual bug, found and fixed while building the drawbridge) and a player walks straight over a `walkable`-flagged collider even while it's toggled to a non-solid sensor (e.g. a drawbridge mid-`closed`, gap meant to be fully exposed) instead of falling through.
- **A solid rect flush with the ground's top edge does not act as a wall.** Two static solid rectangles of the same height that both start at the walking surface resolve as a walkable step under this project's simple AABB collision (`lib/bump`), not a horizontal block — a player can walk straight through at normal standing height. A collider meant to block horizontal entry needs to be taller than the walking surface (see the map's own boundary walls in `Map:createStaticPhysicsBodyBoundary`). The drawbridge doesn't use a barrier at all (closed = gap fully exposed, see the historical `.scratch/drawbridge/` decision log — no longer in-repo), but this still bites anything else that wants a "closed door"-style blocker shaped like a floor tile.
- **A fixture map's declared `height`/`width` must actually contain everything placed in it, kill zones included.** The map's own invisible boundary walls (`Map:createStaticPhysicsBodyBoundary`) are sized off the map's *declared* dimensions, not the extent of its objects. A kill zone placed below the declared map height sits partly or wholly outside the world boundary, which can physically stop a fall (a real solid collision) right at the boundary before it ever reaches the kill zone's interior — looking exactly like "falling doesn't work" rather than "the map is undersized." Size fixture maps generously around any pit/kill-zone geometry, not just the walkable platforms.
The three above were found by `tests/e2e/drawbridge_test.lua` and `tests/integration/drawbridge_test.lua` — real physics (and, for the last one, a real fall all the way to a kill zone) surfaced them; a narrower headless check could not.

The two below were found by `tests/integration/pushable_test.lua`, walking a player across a hole a pushed box had just filled:

- **A body clamped EXACTLY against another's face can never move diagonally away from it, and every frame is diagonal.** `lib/bump`'s `rect_detectCollision` treats exact touching as "already intersecting" (its zero-area intersection case, `rect_containsPoint` on the Minkowski-difference origin) and resolves a diagonal move from there as a horizontal block, returning the body to where it started. Since gravity adds a fractional downward step every frame, a walking body's move is always diagonal — so the body stays welded in place indefinitely. bump's corner-clip exemption (`abs(ti1 - ti2) >= DELTA`) only spares bodies that arrive *mid-stride*, which is why an identical collider is crossed without trouble when approached normally. This was relevant to pushable props: bump clamps a pushing player exactly onto the prop's side face, so if the prop were to vanish mid-fall the player would be left welded to where its face had been. The current design avoids this entirely — `PushableSupport.groupIndexFor` keeps the prop's own collision group at all times, so the prop stays solid and blocks the player while falling. The player waits at the edge until the prop drops below their feet, then walks off freely.
- **A resting prop must be a STATIC body, not a dynamic one at rest.** A dynamic body re-resolves gravity every frame; with its top flush against a walking surface that is enough to keep re-triggering the flush-contact ambiguity above. Switching a settled prop to `static` makes it behave exactly like the terrain it stands in for (the same thing the drawbridge's static deck does) — see `PushableSupport.bodyTypeFor`, and note it must NOT switch while still settling, or it freezes hanging a few pixels above the surface, since support is probed below its feet.

## Physics gotchas when constructing a bare test `Collider` directly

Unlike the two above, these bite in any tier — they're about the physics substrate itself, surfaced by `tests/integration/drawbridge_test.lua` constructing a raw dynamic `Collider` (standing in for an enemy; no enemy entity class exists yet) rather than driving a real `Player`:

- **`collider.groupIndex` defaults to `nil`, and `nil == nil` is `true` in Lua.** `World.colFilter`'s own-group check (`a.groupIndex == b.groupIndex` → ignore the collision) exists so co-op players pass through each other (`Player:init` calls `self.collider:setGroupIndex(-1)`), but it also silently matches any two colliders that never set a `groupIndex` at all — every static terrain/deck/barrier collider included. A hand-built dynamic `Collider` that never calls `setGroupIndex` falls straight through the floor, not because it's unsupported, but because the filter decided it and the ground are "the same group" by coincidence of both being unset. Give any bare test collider a concrete `groupIndex` distinct from `-1`.
- **A one-shot `setLinearVelocity` doesn't survive a stray collision; a real controlled entity's continuous input does.** A single stray one-frame contact (see the next point) can zero `linearVelocityX`. A `Player` self-heals next frame because its FSM reasserts velocity from live input every update regardless of what happened last frame; a bare `Collider` given velocity once and left alone does not, and looks permanently "stuck" instead. Redrive the intended velocity every frame you step, not once before stepping many frames (see `walk()` in `tests/integration/drawbridge_test.lua`).
- **An exact-integer px/s speed at this project's fixed 1/60s timestep can land exactly on a tile boundary and hit a genuine `lib/bump` edge case**, which reports a permanent blocking contact against a walkable surface's edge instead of a normal pass-through (observed at 60px/s, i.e. exactly 1.0px/frame, crossing from one static collider onto an adjacent one). A fractional per-frame step — any speed that isn't a multiple of 60 — never lands exactly on the boundary and never hits it. Real players are incidentally safe here (100px/s ÷ 60 is already fractional); a hand-picked round test speed is not.
