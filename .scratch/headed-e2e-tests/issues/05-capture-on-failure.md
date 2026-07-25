Status: pending

# Automatic capture at the point of failure

## What to build

A contributor whose headed test just failed finds an image of the frame where it failed, without having had to anticipate the failure and place a capture there.

Concretely, after this issue: when an assertion fails during a headed run, the runner automatically captures the current frame before reporting the failure, writing it alongside that test's other captures with a name that makes its origin obvious. The failure output points at the image, so a red test is self-documenting.

## Files to create/modify

- tests/e2e/run.lua — capture the current frame in the assertion-failure path, and reference the image in the failure report
- tests/support/capture.lua — support the failure-capture naming/path if the explicit-capture API doesn't already cover it

## Test approach

Verify with a test that fails on purpose: after the run, an image exists for the failing test, named so its origin is unambiguous, and the failure output names that image's path. Both halves matter — an image nobody is told about is nearly as useless as no image.

Cover the ordering explicitly, because it is easy to get wrong: the capture must be taken at the moment of failure, not after the runner has moved on or torn the scenario down. Verify by failing an assertion at a visually distinctive point in a scenario and confirming the captured frame shows that moment rather than a later or blank one.

Confirm a passing test produces no failure capture, so the directory isn't polluted with images for tests that were fine.

## Acceptance criteria

- [ ] A failing assertion in a headed test automatically produces a capture of the frame at failure.
- [ ] The captured image shows the moment of failure, not a later or torn-down frame.
- [ ] The failure output names the captured image's path.
- [ ] A passing test produces no failure capture.

## Blocked by

04-explicit-frame-capture (reuses the capture writer and output layout).
