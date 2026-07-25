Status: pending

# Three test tiers, shared support and fixtures, four commands

## What to build

A contributor can run any single tier of the test suite, or all of them at once, from consistently-named commands — and it is obvious from a file's location which tier it belongs to and what it costs to run.

Concretely, after this issue:

- `tests/unit/`, `tests/integration/`, and `tests/e2e/` each exist, each holding only its own test files and its own runner.
- Test-support modules and fixture maps live in `tests/support/` and `tests/fixtures/`, shared by every tier rather than owned by one.
- `./test-unit.sh`, `./test-integration.sh`, and `./test-e2e.sh` each run exactly their own tier. `./test-all.sh` runs all three in sequence, reports each tier's outcome, and exits non-zero if any tier failed.
- `./test-all.sh` detects a CI environment via the `CI` environment variable and skips the e2e tier there, printing an explicit skip message. A skipped tier is always announced, never silent.
- `tests/e2e/` is created with a placeholder runner that reports zero tests, so `./test-e2e.sh` and `./test-all.sh` are wired end-to-end before the real headed runner lands in issue 02.

No test logic changes in this issue — this is a move plus a re-point. Every pre-existing test must still pass.

## Files to create/modify

- tests/unit/ — move all of `tests/*_test.lua` here (bump_physics, camera, drawbridge, flash, ground_support, kill_zone, lives, player_movement, runner_smoke, safe_position, timeline_reverse)
- tests/unit/run.lua — moved from `tests/run.lua`; update `defaultTestFiles` paths to `tests/unit/`
- tests/support/game_harness.lua, frame_stepper.lua, fake_input.lua, queries.lua, love_mock.lua — moved from `tests/integration/support/`
- tests/fixtures/flat_ground.lua — moved from `tests/integration/fixtures/`
- tests/integration/run.lua — update the `package.path` line's comment if needed and the `defaultTestFiles` list
- tests/integration/harness_smoke_test.lua, movement_test.lua, all_maps_load_test.lua — update `require` paths from `tests.integration.support.*` to `tests.support.*`, and the fixture path from `tests/integration/fixtures/flat_ground.lua` to `tests/fixtures/flat_ground.lua`
- tests/e2e/run.lua — new placeholder runner (reports zero tests, exits zero)
- test-unit.sh — renamed from `test.sh`, repointed at `tests/unit/run.lua`
- test-integration.sh — repointed if its runner path changes
- test-e2e.sh — new, launches the e2e tier (placeholder behaviour this issue)
- test-all.sh — new, runs all three tiers with CI-aware e2e skip
- tests/README.md — document the three tiers, the four commands, and where support/fixtures live
- AGENTS.md — update the Commands section, which currently documents `./test.sh`

## Test approach

The pre-existing suite *is* the test for this issue: every test that passed before the move must pass after it, run through the new commands. Verify each tier command runs only its own tier, and that `./test-all.sh` aggregates correctly — including that it exits non-zero when a tier fails (temporarily break a test to confirm, then restore).

Verify the CI skip by running `./test-all.sh` with `CI=true` set and confirming the e2e tier is skipped with a visible message while the other tiers still run, and by running it without `CI` and confirming e2e is attempted.

Note the current baseline: `tests/camera_test.lua` has one pre-existing failure unrelated to this work. Confirm the same single failure before and after — do not fix it here, and do not let the move mask or multiply it.

## Acceptance criteria

- [ ] `tests/unit/`, `tests/integration/`, and `tests/e2e/` each exist with their own runner.
- [ ] Shared support modules and fixture maps live outside the tier directories and are imported by the integration tests from their new locations.
- [ ] Every pre-existing unit and integration test passes under the new layout, with the same single known pre-existing camera failure and no new failures.
- [ ] `./test-unit.sh`, `./test-integration.sh`, and `./test-e2e.sh` each run exactly one tier.
- [ ] `./test-all.sh` runs all three tiers, reports each tier's outcome, and exits non-zero if any tier failed.
- [ ] `./test-all.sh` skips the e2e tier when `CI` is set, printing an explicit skip message.
- [ ] `tests/README.md` and `AGENTS.md` describe the new tiers and commands.
- [ ] No test logic was changed as part of the move.

## Blocked by

None — can start immediately.
