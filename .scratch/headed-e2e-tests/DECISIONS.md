# Decisions: Headed E2E Tests and Frame Capture

### Q1: What does "giving a test a head" actually mean here?
**Decision:** Two distinct needs were separated during the grill: watching a scenario play out live in a real window, and capturing what the game looked like at chosen frames. Both were wanted; both were then found to sit on the same axis (see Q6).
- **Why:** The user wants some tests to be watchable "as if watching a playback or recording", and others to just drop screenshots at certain frames. Naming both up front stopped the design collapsing into only one of them.
- **Implication:** The feature has to deliver a real window *and* an image-writing capture API, not one or the other.
- **Alternatives considered:** Recording-only (render off-screen, review a filmstrip afterward) — rejected because the user explicitly wanted a live window for debugging.

### Q2: Live window, or recording reviewed afterward?
**Decision:** A live window, driven by the real LÖVE binary.
- **Why:** The user judged watching it live to be directly useful for debugging.
- **Implication:** Tests can no longer run purely in-process under plain `lua`/`luajit`. Real LÖVE owns a window and an event loop, so headed tests must be launched as a real LÖVE process. This is the "escape hatch to real LÖVE" the integration-testing work deliberately left open rather than closed off.
- **Alternatives considered:** Producing a video file or a folder of frames to review after the fact — rejected as less useful than watching for the specific task of debugging.

### Q3: Which test tier does "headed" belong to?
**Decision:** Its own end-to-end tier. The suite is split three ways: unit, integration, e2e.
- **Why:** Walking through the standard tiers (unit → integration → e2e, plus adjacent categories like smoke, visual regression, and acceptance) made it clear the existing headless integration work already *is* the integration tier — real modules composed, only the engine boundary faked. Real LÖVE with real rendering and a real window is a genuinely different level of the same ladder, exercising the system the way a player meets it.
- **Implication:** Directory layout becomes `tests/unit`, `tests/integration`, `tests/e2e`. The pre-existing unit tests must move into `tests/unit/`, which also means repointing the existing fast-test command.
- **Alternatives considered:** Treating headed as a variant of integration (one folder, runner groups by mode) — initially preferred by the user, then abandoned once the naming inconsistency surfaced (see Q9). Naming the tier `headed` or `visual` instead of `e2e` — not pursued; `e2e` matches the conventional ladder and the user chose the e2e-named command.

### Q4: Does an e2e test differ from an integration test in what it drives?
**Decision:** No. Both drive the same scripted, deterministic scenarios via the same fake-input controller. The only differences are real rendering, watchability, and capture availability.
- **Why:** The user chose this explicitly over making e2e a different *kind* of test (real human input, or covering menu/Slab navigation the integration tier skips). Maximum reuse of the existing harness, minimum new test-writing convention to learn.
- **Implication:** The fake-input controller must shim the keyboard and joystick surfaces even under real LÖVE, where genuine implementations of both exist. Scenario code reads identically in both tiers.
- **Alternatives considered:** E2e as genuinely new ground (real input devices, menu navigation) — rejected as more work covering things not currently needed.

### Q5: How is duplication avoided if the same scenario could run both ways?
**Decision:** It can't run both ways. A test lives in exactly one tier, chosen by whether its assertions need a head. Tests whose point is gameplay state stay in the integration tier; tests whose point is visual go in the e2e tier.
- **Why:** The user's framing: split the *tests*, not the scenario — "the part of the movement system that runs headless into one file, those tests that need a head into a separate file." Since they are different tests rather than the same test twice, there is nothing to duplicate and no shared-scenario extraction layer is needed.
- **Implication:** No mechanism for running one file in two modes; no scenario-extraction indirection. The existing movement tests stay entirely headless and gain no headed twin — a headed movement file would only exist if a genuinely visual assertion were wanted there. Because the tier directory conveys the mode, filenames need no `_head`/`_headless` suffix and keep the existing `_test.lua` convention.
- **Alternatives considered:** One file with an internal "needs head" marker — rejected, as it still makes a scenario one-or-the-other while adding a marker to parse. Shared scenario plus two thin per-mode wrappers — rejected as unnecessary indirection once it was clear the tests differ rather than repeat.

### Q6: Can headless tests take screenshots too?
**Decision:** No. Capture requires real rendering, so a test that wants a capture is by definition a headed (e2e) test.
- **Why:** The headless mock's graphics calls are no-ops returning fake images — there is literally nothing rendered to capture. Real capture needs a real graphics context, which LÖVE ties to a window. The two capabilities therefore stack on one axis rather than being independent knobs.
- **Implication:** The capture API lives in shared support but must fail loudly when called outside the e2e tier (see Q13). The mode matrix has exactly two rows: headless-mock (fast, in-process, no capture) and headed-real-LÖVE (slow, subprocess, capture available).
- **Alternatives considered:** A third middle mode — real LÖVE with the window hidden/minimised/off-screen, giving real rendering and captures without anything to watch, useful for capture-producing CI runs. Explicitly rejected by the user in favour of just two modes. (It was also flagged that LÖVE's ability to suppress the window while keeping graphics alive would need verifying, which is now moot.)

### Q7: How are frames advanced under real LÖVE, and how fast?
**Decision:** The simulated timestep stays fixed at the harness's existing value, always. Pacing is a separate concern: by default a headed run advances as fast as it can (many simulated frames per drawn frame, finishing quickly), and a flag paces it to one simulated frame per drawn frame so playback matches real time.
- **Why:** The user wanted fast-by-default with an opt-in slowdown "so it looks like a normal play through". Keeping dt fixed independently of pacing means fast and slow runs produce byte-identical gameplay — the flag only controls whether the runner waits between frames.
- **Implication:** The runner drives the simulation from LÖVE's own update callback rather than a synchronous loop, so frames are genuinely drawn and presented. Determinism is preserved across both pacing modes, so a scenario watched in slow mode and one blasted through in fast mode cannot disagree.
- **Alternatives considered:** Real-time pacing always — rejected as needlessly slow when only captures are wanted. Playback controls (pause, step, slow-motion toggle) — deferred; the user accepted plain playback with a pacing flag for the first version, and real input is ignored anyway (see Q12).

### Q8: How are captures triggered, and where do they go?
**Decision:** All three triggers, composing freely: explicit named captures from scenario code, an automatic capture at the point an assertion fails, and an optional every-Nth-frame filmstrip. Output goes to a gitignored directory under the test tree. The filmstrip interval is configurable and the filmstrip is disabled by default.
- **Why:** The user wanted all three. Gitignored because these are debugging artifacts, not committed baselines — committing them would only make sense for visual regression testing, which is explicitly out of scope. The filmstrip defaults off (a later refinement by the user) so a normal headed run isn't buried in hundreds of images.
- **Implication:** Captures are organised per test so a run's output is findable and clearable. The failure-triggered capture is what makes a red headed test self-documenting.
- **Alternatives considered:** Explicit-only captures — rejected, loses the automatic evidence on failure that motivated the feature. Filmstrip on by default — rejected by the user as too noisy.

### Q9: Command naming, and where headed files live
**Decision:** A separate `test-e2e.sh`-style command, with headed files living in `tests/e2e/` so the folder matches the command. Four commands total: one per tier plus an aggregate.
- **Why:** The user first chose a separate e2e command, which immediately created a naming conflict with the earlier "keep everything in `tests/integration/`" idea — a command named for e2e reaching into a folder named for integration. Resolved by matching folder to command, which also restored the original three-folder structure the user first asked for. The fast unit command is renamed for consistency with the other three.
- **Implication:** The pre-existing fast-test command name changes, which is a small break in muscle memory and in any docs referencing it. Each tier has exactly one runner and one command.
- **Alternatives considered:** Headed files in `tests/integration/` with a filename convention, picked out by the e2e command — rejected for the folder/command mismatch. Keeping the fast command's original name — rejected by the user in favour of consistent naming across all four.

### Q10: Does the aggregate command include the e2e tier?
**Decision:** Yes, all three tiers — but it detects a CI environment and skips the e2e tier there, reporting the skip explicitly.
- **Why:** The user wanted a genuine "run everything" command, without it being unusable in CI. E2e needs a real display and the real LÖVE binary, neither of which exists in a headless CI runner.
- **Implication:** Detection uses the conventional `CI` environment variable, which the project's GitHub Actions workflows set automatically. The skip must be announced, never silent — a silently skipped tier reads as "everything passed" when a third of the suite never ran.
- **Alternatives considered:** Aggregate covering unit + integration only, with e2e always deliberate — rejected as less useful. Hard-failing when the LÖVE binary or display is missing — superseded by CI detection, though the underlying question of a missing binary outside CI remains an implementation concern.

### Q11: How does LÖVE get pointed at a test instead of the game?
**Decision:** A launch argument on the existing entry point, following the same style as the existing map-selection and debug-drawing arguments. The entry point detects it and hands control to the e2e runner instead of constructing the normal game.
- **Why:** Chosen by the user over a separate entry point. It reuses an argument-parsing pattern already present and understood in this codebase, and avoids a second entry point that would have to stay in sync with how the real one bootstraps globals.
- **Implication:** Production entry-point code gains a small amount of test-awareness — an accepted cost. The tradeoff was made knowingly: the alternative's sync burden was judged worse than the coupling.
- **Alternatives considered:** A dedicated test entry point (its own main/conf) that LÖVE is pointed at directly, keeping test concerns entirely out of production code — rejected for the duplication of global bootstrapping it would require.

### Q12: One LÖVE process per test file, or one for the whole run?
**Decision:** One LÖVE process per test file.
- **Why:** Clean isolation — a crash or a wedged scenario cannot affect the remaining files. Chosen over the faster single-process model.
- **Implication:** Startup cost (roughly a second) multiplies per file, and a window opens and closes per file. The tier's command must iterate files, launch a process each, and aggregate outcomes into one summary and exit status. Cross-file state leakage (notably the map library's module-level image cache, which persists where `world`/`map` are already recreated per game start) stops being a concern.
- **Alternatives considered:** One process for the whole run — nicer to watch back-to-back and much faster, but rejected for the crash-isolation and state-reset risks.

### Q13: Real input and abort behaviour during a headed run
**Decision:** Real physical input is ignored entirely — gameplay stays fully scripted. Closing the window mid-run reports the run as cancelled, distinct from a failure. Calling the capture API from the headless tier errors loudly.
- **Why:** Ignoring real input keeps a watched test deterministic and un-perturbable by touching the machine. Cancelled-not-failed means aborting a debugging session doesn't masquerade as a regression. Erroring on a headless capture attempt avoids the trap of a silent no-op leaving you wondering why no image appeared.
- **Implication:** There are no harness control keys (no pause, step, or speed toggle) — pacing is chosen up front by flag instead. The runner needs three distinct outcomes (pass, fail, cancelled), not two.
- **Alternatives considered:** Honouring specific real keys as harness controls while keeping gameplay scripted — rejected by the user. Treating window close as a failure so it can never be silently ignored — rejected in favour of the clearer cancelled report. Silent no-op for headless captures — rejected as a debugging trap.

### Q14: What is the first real e2e scenario?
**Decision:** The drawbridge crossing, against the existing drawbridge fixture map.
- **Why:** It is the concrete case that motivated this whole feature. The drawbridge's spatial acceptance criteria — the deck turning solid before the player reaches the gap so no fall occurs, and a wrong-side approach staying blocked — were explicitly deferred to a manual game launch because the headless harness can neither show nor capture the crossing. Those criteria are exactly what a headed test with captures at the approach, open, and crossed moments can make repeatable.
- **Implication:** Completing this feature unblocks verification work that is currently marked as blocked on repro-ability, and replaces a manual, unreviewable step with an automated one. The scenario asserts gameplay state through existing query helpers, with captures as supporting evidence, so it fails on behaviour rather than appearance.
- **Alternatives considered:** Porting the existing movement scenario as a low-risk proving ground — not chosen as the target, though a trivial smoke scenario is still needed earlier to prove the runner itself works.

### Q15: Shared support and fixture location
**Decision:** Shared test infrastructure moves up out of the integration directory: support modules and fixture maps get their own directories, leaving each tier directory holding only its own test files and runner.
- **Why:** The e2e tier needs almost all of it — the game bootstrap, frame stepping, fake input, query helpers, and the fixture maps. Only the headless love mock is genuinely integration-specific, and it costs nothing to keep it alongside the rest.
- **Implication:** Existing import paths in the integration tests change as part of the restructure. This makes the restructure a genuine prerequisite for the e2e work rather than optional tidying.
- **Alternatives considered:** E2e reaching across into the integration directory's support folder, leaving current paths untouched — rejected by the user; it would have made the integration tier look like the owner of infrastructure both tiers depend on.

## Key Assumptions

- The real LÖVE binary is available locally for headed runs, discovered the same way the project's existing run script does it (a local bundled binary if present, otherwise the system one on PATH). Behaviour when it is absent outside CI is an implementation concern to settle during the first e2e slice.
- Writing captured images to an arbitrary path in the project tree is achievable from inside LÖVE. This needs verifying early: LÖVE's filesystem writes are normally confined to a save directory, so encoding image data in memory and writing it out through plain Lua file I/O is the likely route. This is the load-bearing assumption of the capture work.
- The conventional `CI` environment variable is a sufficient CI signal for skipping the e2e tier; the project's GitHub Actions workflows set it automatically.
- The physics backend default and the existing decision to start scenarios directly in the in-game state both continue to hold, inherited from the integration harness.
- Real LÖVE's own implementations of the input surfaces can be shimmed by the fake-input controller at runtime. If any entity input path bypasses the shimmed surface, scenarios would drift under real LÖVE — worth watching for during the first headed scenario.

## CONTEXT.md updates

New glossary entries added:
- **Headed test** — the e2e tier's real-LÖVE, real-rendering, watchable test, distinguished from the existing headless `Integration test` entry.
- **Frame capture** — the still-image dump of a rendered frame used as debugging evidence, distinguished from visual regression testing.

The existing `Integration test` entry is amended to note it is now one of three tiers and remains the headless one, so it no longer reads as though it is the only map-loading test category.
