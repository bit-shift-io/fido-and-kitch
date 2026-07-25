Status: pending

# Optional filmstrip capture at a configurable interval

## What to build

A contributor investigating something time-ordered can capture every Nth frame of a headed run and scrub through the whole scenario frame by frame afterward — and a normal headed run produces nothing extra, because the filmstrip is off unless explicitly asked for.

Concretely, after this issue:

- A flag on `./test-e2e.sh` enables filmstrip capture and sets the interval N, so the run captures every Nth simulated frame.
- The interval is configurable rather than fixed.
- Filmstrip capture is disabled by default. A run that doesn't ask for it produces only explicit captures and any failure capture.
- Filmstrip frames are written in a way that sorts in scenario order, so scrubbing through them follows the run.

## Files to create/modify

- test-e2e.sh — accept the filmstrip flag and interval, forward to LÖVE as a launch argument
- tests/e2e/run.lua — count simulated frames and trigger a capture on the interval when enabled
- tests/support/capture.lua — support filmstrip frame naming if the explicit-capture API doesn't already cover it

## Test approach

Verify the default first, since it is the property most easily lost: a headed run with no filmstrip flag produces zero filmstrip images. Then verify enabling it with a known interval over a known frame count produces the expected number of images — an off-by-one in the interval check shows up here and nowhere else.

Verify the interval is genuinely honoured rather than hardcoded, by running the same scenario at two different intervals and confirming the image counts differ accordingly.

Confirm the filenames sort in scenario order — naive numbering breaks lexical sort once the frame count passes a power of ten, which would make scrubbing misleading rather than merely ugly.

## Acceptance criteria

- [ ] A flag enables filmstrip capture with a configurable interval.
- [ ] Filmstrip capture is disabled by default; a run without the flag produces no filmstrip images.
- [ ] A known interval over a known frame count produces the expected image count, and different intervals produce different counts.
- [ ] Filmstrip filenames sort in scenario order, including past a power-of-ten frame count.

## Blocked by

04-explicit-frame-capture (reuses the capture writer and output layout).
