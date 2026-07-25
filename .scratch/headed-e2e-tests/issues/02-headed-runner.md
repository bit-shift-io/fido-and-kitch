Status: pending

# Headed runner: real LÖVE, real rendering, scripted input

## What to build

A contributor can run an e2e test and watch it play out in a real LÖVE window, with real rendering, while the scenario stays fully scripted and deterministic — and the shell learns whether it passed, failed, or was cancelled.

Concretely, after this issue:

- `./test-e2e.sh` iterates the e2e tier's test files and launches one real LÖVE process per file, aggregating their outcomes into one summary and one exit status (non-zero if any file failed).
- LÖVE is pointed at a test file through a new launch argument on the existing entry point, in the same style as the existing `map=`, `debug`, and `drawphysics` arguments. The entry point detects it and hands control to the e2e runner instead of constructing the normal `Game`.
- The e2e runner exposes the same `test()` and assertion surface as the other tiers' runners, so scenario code reads identically across tiers.
- The simulation advances at the harness's existing fixed timestep, driven from LÖVE's own update callback so frames are genuinely drawn and presented. (Pacing is fast-as-possible here; the real-time flag is issue 03.)
- Gameplay input stays scripted: the fake-input controller shims the keyboard and joystick surfaces even though real LÖVE provides genuine ones, so entity input queries read test-driven state. Real physical input has no effect.
- The runner distinguishes three outcomes — pass, fail, and cancelled. Closing the window mid-run reports cancelled and does not mark outstanding tests as failed.
- One trivial headed scenario proves it end to end: load the shared flat-ground fixture, step frames with real rendering, assert a player spawned.

## Files to create/modify

- src/main.lua — detect the new e2e launch argument and hand off to the e2e runner instead of constructing `Game`
- tests/e2e/run.lua — replace issue 01's placeholder with the real in-LÖVE runner: `test()`/`assert*` surface, frame driving from `love.update`, fixed timestep, pass/fail/cancelled reporting, non-zero exit on failure
- tests/e2e/harness_smoke_test.lua — the trivial proving scenario
- tests/support/fake_input.lua — shim the keyboard/joystick surfaces under real LÖVE as well as under the mock
- tests/support/game_harness.lua — support starting a game against real LÖVE (do not install the headless mock in this mode)
- test-e2e.sh — replace placeholder behaviour: discover e2e test files, launch one LÖVE process each, aggregate outcomes and exit status

## Test approach

The smoke scenario is the verification, but it must genuinely prove the headed path rather than accidentally passing headless. Confirm that real rendering actually happened (the mock's no-op graphics are not in play) and that a window appeared — not merely that the process exited zero.

Cover the outcome plumbing explicitly, since it is the contract with the shell: a passing file exits zero; a file with a failing assertion exits non-zero and names the failing test; closing the window mid-run reports cancelled and is distinguishable from a failure in both the output and the exit status.

Verify input isolation by holding a real key on the physical keyboard while a scenario runs and confirming the scenario's outcome is unchanged — this is the assertion that the shim is genuinely in front of real LÖVE's input, and it is worth doing by hand once.

Verify the per-file process model by running a tier containing two files and confirming two separate processes, and that a deliberately crashing first file does not prevent the second from running.

## Acceptance criteria

- [ ] `./test-e2e.sh` launches one real LÖVE process per e2e test file and aggregates outcomes into one summary and exit status.
- [ ] LÖVE reaches the e2e runner via a launch argument on the existing entry point, following the existing argument style.
- [ ] The e2e runner offers the same `test()`/assertion surface as the other tiers.
- [ ] A headed scenario renders real frames in a real window while advancing at the fixed timestep.
- [ ] Gameplay input is scripted through the fake-input controller; real physical keyboard/gamepad input has no effect on a running scenario.
- [ ] A failing assertion exits non-zero and names the failing test.
- [ ] Closing the window mid-run reports the run as cancelled, distinct from a failure, and does not mark outstanding tests failed.
- [ ] A crash in one test file does not prevent remaining files from running.

## Blocked by

01-tier-restructure (needs the e2e tier directory, the shared support location, and the wired-up command).
