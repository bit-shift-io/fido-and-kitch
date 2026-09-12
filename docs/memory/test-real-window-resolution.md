---
name: test-real-window-resolution
description: Camera/framing tests that hardcode a screen size (e.g. 800x600) can all pass while the logic is broken at the game's real window resolution and aspect ratio.
metadata:
  type: convention
---

The Voronoi split trigger once compared a required framing scale of `min(screenW/bw, screenH/bh)` against a cap floor scale of `max(screenW, screenH)/(capTiles*tile)`. Those two ratios are each governed by a *different* screen dimension, so their relationship depends on the window's aspect ratio. At the ~4:3 resolution every test hardcoded (800x600) they agreed; at the game's real 16:9 window (1280x720, from `conf.lua`) they did not, and the split fired for every player arrangement. Every tier missed it — unit, integration, and even e2e, which runs the real LÖVE binary but called `love.window.setMode(800, 600)` in each test.

**Why:** A screen-space calculation can encode an implicit aspect-ratio assumption that only breaks at a *different ratio*, not a different size — so testing several resolutions at one aspect ratio catches nothing. Screen-space is not itself the problem: the trigger is screen-space again today (players' on-screen separation vs. the split regions' centroid separation) and is correct, because both sides of that comparison are screen-space distances measured the same way. The defect is mixing spaces, or letting the two sides be governed by different dimensions.

**How to apply:** When adding or changing camera/framing/viewport logic that touches `screenW`/`screenH` (or `love.graphics.getWidth/getHeight`), check that both sides of any comparison are in the same space and governed by the same dimensions. Then test it at the project's real configured resolution — read it from `conf.lua` rather than reusing the suite's usual constants — alongside at least one clearly different aspect ratio. `tests/unit/camera_test.lua` has a resolution-sweep test and `tests/e2e/split_screen_test.lua` has one that deliberately omits `setMode` so it runs at the real default; extend those rather than adding another 800x600 case.
