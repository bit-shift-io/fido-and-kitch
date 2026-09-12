---
name: camera-zoom-range-drives-parallax
description: Changing the camera's zoom-out range silently changes parallax strength, because map_parallax normalises against the full-map scale.
metadata:
  type: project
---

`src/map/map_parallax.lua`'s `computeZoomT` normalises the current camera scale between the full-map view and the closest view, and that 0..1 value lerps the parallax allowance between `ZOOMED_OUT_ALLOWANCE` (0.10) and `ZOOMED_IN_ALLOWANCE` (0.30). Nothing in the camera knows this.

**Why:** Any change to how far the camera may zoom out — a cap, a new minimum view size, a different padding rule — moves one end of that normalisation, so background layers slide by a different amount at the same gameplay zoom. The change is invisible in `tests/unit/camera_test.lua` and only shows as backgrounds that feel wrong.

**How to apply:** When you touch the camera's zoom range, run `tests/unit/map_parallax_test.lua` and then look at a map with a parallax background by eye. If the follow camera can no longer reach the full-map scale at all, decide deliberately what `computeZoomT` should normalise against instead of letting it normalise against a scale that never occurs.
