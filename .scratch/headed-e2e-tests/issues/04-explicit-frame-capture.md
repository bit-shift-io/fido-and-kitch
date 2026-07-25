Status: pending

# Explicit named frame capture

## What to build

A contributor can capture what the game looks like at a chosen moment in a headed scenario, by name, and find the resulting image on disk afterward — and gets a loud, explanatory error if they try the same thing from a headless test where it cannot work.

Concretely, after this issue:

- Scenario code can request a named capture at any point in a headed run, and a real image of that frame is written to disk.
- Captures land in a dedicated directory under the test tree, organised per test so a run's output is easy to find and to clear, and that directory is ignored by git.
- Calling the capture function from the headless tier raises an explicit error naming the e2e tier as the requirement. It is never a silent no-op — a silent no-op leaves you wondering why no image appeared.

## Files to create/modify

- tests/support/capture.lua — new: the capture API, shared so scenario code references it uniformly across tiers, erroring when the current tier cannot render
- tests/e2e/run.lua — wire the capture API to the live rendering context and the current test's output location
- tests/e2e/harness_smoke_test.lua — extend with a named capture, so the tier's own smoke scenario exercises the feature
- .gitignore — ignore the capture output directory
- tests/README.md — document where captures land and how to trigger one

## Test approach

**Verify the riskiest assumption first, before building on it:** LÖVE's filesystem writes are normally confined to a save directory, so writing an image to an arbitrary path in the project tree needs proving against the real runtime early. The likely route is encoding the frame's image data in memory and writing it out through plain Lua file I/O rather than the engine's filesystem write. Establish which approach actually works before wiring the rest of the API on top of it.

Then assert on the artifact, not the call: after a scenario requesting a named capture, the expected file exists at the expected path and is a real encoded image of non-trivial size — not a zero-byte file. A test that only checks the function returned without error would pass against a broken writer.

Cover the headless guard as its own case: a headless test calling the capture function fails with an error whose message names the e2e tier, and the error is raised rather than swallowed.

Confirm by opening one captured image that it shows the rendered game frame — a file of plausible size that is actually blank or garbage would satisfy every automated assertion above while being useless for the debugging this feature exists to serve.

## Acceptance criteria

- [ ] Scenario code can request a named capture during a headed run.
- [ ] The image is written to the per-test capture directory under the test tree, and is a real encoded image of non-trivial size.
- [ ] An opened capture visibly shows the rendered game frame.
- [ ] The capture output directory is gitignored.
- [ ] Calling the capture function from the headless tier raises an explicit error naming the e2e tier; it is not a silent no-op.
- [ ] `tests/README.md` documents capture output location and usage.

## Blocked by

02-headed-runner (needs a live rendering context to capture from).
