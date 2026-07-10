Status: pending

# Smooth camera motion and level-start zoom-in

## What to build

The camera now glides instead of snapping: as players move, jump, and separate, camera centre and zoom ease smoothly toward the target view — slick, no jitter, settling in under roughly half a second. On level load the camera starts at the full-map view and smoothly zooms in on the players, giving a level-intro flourish.

Implementation: frame-rate-independent exponential lerp (decay parameterised by dt) applied to camera centre and zoom, between the target view computed by issue 01's framing math and the current view actually used for drawing. Smoothing constants live in one obvious tunable place. On level load the current view is initialised to the full-map view while the target is the player framing.

## Files to create/modify

- src/camera.lua (smoothing state + update(dt))
- src/game_states.lua (InGameState:load initialises camera at full-map view; update ticks the camera)
- tests/camera_test.lua (smoothing tests)

## Test approach

Headless tests: simulate updates toward a fixed target and assert convergence (within epsilon of target after ~0.5s of simulated time); frame-rate independence (dt=1/30 vs dt=1/120 reach approximately the same view after the same simulated time); no overshoot. Level-start test: camera constructed with full-map initial view reports full-map view on frame one, then converges to the follow target. Manual: jump around — no jitter; reload a level — visible zoom-in intro.

## Acceptance criteria

- [ ] Camera pan and zoom are smooth with no snapping or jitter during jumps
- [ ] Motion settles in under ~half a second, constants tunable in one place
- [ ] Smoothing is frame-rate independent
- [ ] Level start opens at full-map view and eases in on the players
- [ ] Headless smoothing tests pass via `./test.sh`

## Blocked by

01
