Status: pending

# Real-time pacing flag for watchable playback

## What to build

A contributor can choose between blasting a headed run through as fast as it will go (the default, for producing captures quickly) and pacing it to real time so the scenario plays back at normal speed and is genuinely watchable.

Concretely, after this issue:

- By default, a headed run advances as many simulated frames per drawn frame as it can, finishing as quickly as the machine allows.
- A flag on `./test-e2e.sh` switches it to advancing one simulated frame per drawn frame, so playback matches real time.
- The simulated timestep is unchanged by the flag. Only whether the runner waits between frames changes, so a scenario run fast and the same scenario run paced produce identical gameplay state.

## Files to create/modify

- tests/e2e/run.lua — honour the pacing mode when advancing frames
- test-e2e.sh — accept the pacing flag and forward it to LÖVE as a launch argument

## Test approach

The load-bearing property here is that pacing does not affect gameplay, so test exactly that: run the same scenario in both modes and assert the resulting gameplay state is identical (same final position, same facing, same state), not merely that both passed. If the two disagree, the timestep has leaked into the pacing path and determinism is broken.

Verify the observable difference is wall-clock only: the paced run of a known frame count takes roughly the expected real time, the default run takes materially less.

Confirm by watching once that a paced run is actually watchable at normal speed — this is the whole point of the flag and is worth eyeballing rather than only measuring.

## Acceptance criteria

- [ ] A headed run advances as fast as it can by default.
- [ ] A flag paces the run to real time, one simulated frame per drawn frame.
- [ ] The same scenario produces identical gameplay state in both modes.
- [ ] A paced run's duration reflects its frame count in wall-clock terms; the default run is materially faster.

## Blocked by

02-headed-runner (needs the frame-driving loop the flag modifies).
