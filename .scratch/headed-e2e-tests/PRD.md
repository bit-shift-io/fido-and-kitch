# Headed E2E Tests and Frame Capture

## Problem Statement

The integration test harness runs entirely headless: every `love.graphics` call is a no-op against a minimal `love.*` mock. That makes the suite fast and CI-friendly, but it means a failing gameplay test gives you nothing but a line of text. When a test says the player ended up at the wrong x, or the drawbridge deck wasn't solid in time, there is no way to *see* what happened — you drop back to launching the game by hand and trying to reproduce the moment with your eyes.

This bites hardest on mechanics whose correctness is inherently spatial and time-ordered. The drawbridge is the live example: its acceptance criteria ("the deck becomes solid before the player reaches the gap — no fall", "a wrong-side approach is blocked") were explicitly deferred to a manual `love . drawphysics map=drawbridge_fixture.lua` run, because the headless harness can neither show the crossing nor capture it. That manual step is unrepeatable, unreviewable, and invisible to anyone (human or AI agent) who wasn't sitting at the keyboard when it ran.

Separately, the test suite has outgrown its layout. Unit tests and integration tests now live at two different levels of the same `tests/` directory with no consistent naming, and adding a third category with different runtime requirements would make that worse.

## Solution

Split the suite into three explicit tiers — unit, integration, and end-to-end — each in its own directory with its own command, sharing one set of test-support modules and fixture maps.

The new **e2e tier** runs the same kind of scripted, deterministic scenario the integration tier does — same simulated input, same fixed timestep, same gameplay assertions — but under the real LÖVE runtime with a real window and real rendering. Because the frames are genuinely drawn, an e2e test can be *watched* while it runs and can *capture* what the game looked like at any moment to an image file on disk. Those images are the deliverable: a human can eyeball them, and an AI agent can read them, without either needing to have been present when the test ran.

Headed runs stay deliberate. The existing headless suite is untouched and just as fast, and the aggregate command skips the e2e tier automatically in CI, where no display exists.

## User Stories

1. As a contributor, I want the suite organised into unit, integration, and e2e tiers, each with its own command, so it is obvious where a new test belongs and what it costs to run.
2. As a contributor, I want one aggregate command that runs every tier, so I can check everything before pushing without remembering three commands.
3. As a contributor, I want that aggregate command to skip the e2e tier automatically when running in CI, so a display-less CI environment doesn't fail on tests it fundamentally cannot run.
4. As a contributor, I want test-support modules and fixture maps shared across tiers, so an e2e test and an integration test can drive the same harness and load the same fixture without duplication.
5. As a contributor, I want to write an e2e test using the same `test()`/assertion style and the same input-driving helpers as an integration test, so moving a scenario between tiers costs almost nothing to learn.
6. As a contributor debugging a mechanic, I want to watch an e2e test play out in a real window, so I can see what the scenario actually does rather than inferring it from assertion output.
7. As a contributor, I want a headed run to advance as fast as it can by default, so producing captures is quick when I don't need to watch.
8. As a contributor, I want a flag that paces a headed run to real time, so a scenario plays back at normal speed and is actually watchable.
9. As a contributor, I want the simulation to advance at a fixed timestep regardless of pacing, so a scenario behaves identically whether I watched it or blasted through it.
10. As a contributor, I want to capture a named screenshot at a chosen point in a scenario, so I get an image of exactly the moment I care about.
11. As a contributor whose test just failed, I want the harness to have captured the frame at the point of failure automatically, so a red test always leaves visual evidence behind.
12. As a contributor investigating something time-ordered, I want to optionally capture every Nth frame with a configurable interval, so I can scrub through a whole scenario frame by frame.
13. As a contributor, I do not want filmstrip capture running unless I ask for it, so a normal headed run isn't buried in hundreds of images.
14. As a contributor, I want captured images written to a gitignored location, so debugging artifacts never end up committed.
15. As a contributor who mistakenly calls capture from a headless test, I want a loud error explaining captures need the e2e tier, so I'm never left wondering why no image appeared.
16. As a contributor, I want gameplay input in a headed test to stay fully scripted and ignore my real keyboard and gamepad, so a test I'm watching cannot be perturbed by touching the machine.
17. As a contributor watching a headed run, I want closing the window to report the run as cancelled rather than failed, so aborting a debugging session doesn't look like a real regression.
18. As a contributor, I want each e2e test file to run in its own LÖVE process, so a crash or a wedged scenario cannot take down the rest of the run.
19. As a maintainer, I want an e2e test covering the drawbridge crossing with captures at the approach, open, and crossed moments, so the mechanic's spatial acceptance criteria stop depending on someone running the game by hand.

## Implementation Decisions

- The suite is reorganised into three tier directories (unit, integration, e2e), each holding its own test files and its own runner, with shared test-support modules and shared fixture maps promoted to their own directories one level up. Every existing test moves into the tier it already belongs to; no test logic changes as part of the move.
- Each tier gets its own top-level command, named consistently, plus one aggregate command that runs all three in sequence and reports each tier's result. The aggregate command detects a CI environment via the conventional `CI` environment variable and skips the e2e tier with an explicit message when set — a skip is always reported, never silent.
- A test belongs to exactly one tier. There is no mechanism for running the same test file both headless and headed: a scenario whose assertions are pure gameplay state lives in the integration tier, and one whose point is visual (needing captures or a watchable playback) lives in the e2e tier. The tier directory conveys the mode, so test filenames need no head/headless suffix and keep the existing `_test.lua` convention.
- The e2e tier runs under the real LÖVE runtime, reached through a new launch argument on the existing entry point, following the same argument style already used for selecting a map and enabling debug drawing. The entry point detects the argument and hands control to the e2e runner instead of constructing the normal game.
- The e2e runner is launched once per test file, as a separate LÖVE process. The tier's shell command iterates the tier's files, launches a process for each, and aggregates their outcomes into one summary and one exit status.
- The e2e runner exposes the same `test()` and assertion surface as the other tiers' runners, so scenario code reads identically across tiers.
- Under real LÖVE, the simulation is driven from the engine's own update callback rather than a synchronous loop, so frames are genuinely drawn and presented. The simulated timestep stays fixed at the same value the headless harness uses, independent of real elapsed time, so scenarios remain deterministic.
- Pacing is separate from timestep. By default a headed run advances as many simulated frames per drawn frame as it can, finishing quickly. A flag switches it to advancing one simulated frame per drawn frame, so playback matches real time and is watchable. Both modes produce identical gameplay.
- Input in the e2e tier stays scripted: the existing fake-input controller shims the keyboard and joystick surfaces even under real LÖVE, so entity input queries read test-driven state rather than the physical device. Real physical input is ignored entirely — there are no harness control keys.
- Closing the window mid-run is treated as a cancellation, distinct from both pass and failure: the runner reports the run as cancelled and does not mark outstanding tests as failed.
- Frame capture is a first-class part of the e2e runner, available three ways, which compose freely: an explicit named capture invoked from scenario code; an automatic capture taken at the point an assertion fails; and an optional filmstrip capturing every Nth frame, whose interval is configurable and which is disabled unless explicitly requested.
- Captured images are written to a dedicated directory under the test tree, added to the project's ignore rules, and organised per test so a run's output is easy to find and to clear.
- The capture function exists in the shared test-support layer so scenario code can reference it uniformly, but invoking it outside the e2e tier raises an explicit error naming the reason — captures require real rendering, which the headless mock cannot provide.
- The first real e2e scenario covers the drawbridge crossing against the existing drawbridge fixture map, capturing the approach, the opening transition, the fully open deck, and the completed crossing, plus the blocked wrong-side approach.

## Testing Decisions

- This feature is test infrastructure, so "what makes a good test" applies at two levels: the infrastructure itself must be verified by using it, and the scenarios it enables must assert observable gameplay state rather than internals.
- Each infrastructure slice is verified by a real scenario exercising it end-to-end, not by unit-testing the harness internals: the tier restructure is proven by every pre-existing test still passing under the new commands, the e2e runner by a trivial scenario that loads a fixture and renders real frames, and each capture trigger by the image files it actually produces on disk.
- Capture assertions check that the expected image files exist and are non-trivial (a real encoded image, not an empty file). Asserting on image *content* is deliberately excluded — that would be visual regression testing, which is a different goal with different machinery (see Out of Scope).
- The drawbridge scenario asserts gameplay state through the existing query helpers (position advanced across the gap, no death/fall occurred, a wrong-side approach leaves the player blocked) with captures as supporting evidence, so the test fails on behaviour rather than on appearance.
- Prior art: the existing integration tier already establishes the pattern this feature extends — real modules composed together with only the engine boundary faked, scenarios driven by simulated input across stepped frames, and assertions on gameplay state through small query helpers. The pure decision helpers extracted for the drawbridge state machine are the model for keeping logic testable without the rendering stack.
- File naming and location follow this project's established Lua convention rather than the generic `.unit.test.ts` / `.integration.test.ts` scheme: test files keep the `_test.lua` suffix, and the tier is expressed by which tier directory a file lives in. Shared support modules and fixtures sit in their own directories outside the tier directories.

## Out of Scope

- Visual regression testing — comparing captures against committed baseline images to detect unintended rendering changes. This feature produces captures for humans and agents to read, not to diff. Baseline management, tolerance thresholds, and platform rendering differences are all deliberately avoided.
- Running the same test file in both modes. Tier membership is exclusive by design.
- Harness control keys during a headed run (pause, step, slow-motion toggle, rewind). Real input is ignored entirely; pacing is chosen up front by flag.
- Video/animation output. Captures are still images; a filmstrip is a directory of stills, not an encoded video.
- A hidden-window or off-screen rendering mode for producing captures without a visible window. Only two modes exist: headless-mock and headed-real-LÖVE.
- Driving menu or Slab UI navigation. The e2e tier inherits the existing decision to start directly in the in-game state.
- Wiring the new commands into the CI workflow definitions. The aggregate command is made CI-aware, but changing the workflow files themselves is not part of this feature.
- Migrating the deferred pressure-switch integration test, or implementing the pressure switch entity it depends on.
- Audio, and any LÖVE subsystem beyond graphics/input needed to render and drive a scenario.

## File Structure

```
tests/
  support/         -- shared harness: game bootstrap, frame stepping, fake input,
                      query helpers, the headless love mock, capture API
  fixtures/        -- shared fixture maps
  unit/            -- unit tests + runner
  integration/     -- headless integration tests + runner
  e2e/             -- headed tests + in-LÖVE runner
  screenshots/     -- capture output, gitignored
test-unit.sh
test-integration.sh
test-e2e.sh
test-all.sh
```

## Acceptance Criteria

- [ ] The suite is split into unit, integration, and e2e tier directories, with shared support modules and fixtures promoted out of the integration directory.
- [ ] Each tier has its own command, and every pre-existing test still passes under the new layout with no test logic changed.
- [ ] An aggregate command runs all three tiers, reports each tier's outcome, and exits non-zero if any tier fails.
- [ ] The aggregate command skips the e2e tier when a CI environment is detected, and says so explicitly.
- [ ] An e2e test runs under real LÖVE via a launch argument on the existing entry point, in its own process per test file, and reports pass/fail back to the shell with a non-zero exit status on failure.
- [ ] An e2e test drives gameplay with the same scripted input helpers as an integration test, and real physical keyboard/gamepad input has no effect on it.
- [ ] A headed run advances as fast as it can by default, and a flag paces it to real time; both produce identical gameplay state.
- [ ] Closing the window mid-run reports the run as cancelled, distinct from a failure.
- [ ] Scenario code can capture a named screenshot, and the image appears in the gitignored capture directory.
- [ ] A failing assertion in a headed test automatically produces a capture of the frame at failure.
- [ ] Filmstrip capture is available with a configurable interval and is disabled by default.
- [ ] Calling the capture function from the headless tier raises an explicit error naming the e2e tier as the requirement.
- [ ] An e2e test covers the drawbridge crossing — correct-side approach opens the deck and the player crosses without falling, wrong-side approach stays blocked — with captures at the approach, open, and crossed moments.

## References

- The existing integration harness and the decisions behind it, including the deliberate headless-mock-with-escape-hatch choice this feature is the follow-through on.
- Glossary entries for `Fast gameplay regression test`, `Integration test`, `Fixture map`, and the new `Headed test` / `Frame capture` entries added by this feature.
- The drawbridge mechanic's glossary entry and its outstanding spatial acceptance criteria, which the first e2e scenario is written to cover.
- Project agent context for the physics backend default, entity/map conventions, and the existing launch-argument style the e2e argument follows.
