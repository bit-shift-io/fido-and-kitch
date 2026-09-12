---
name: split-camera-merge-release-must-converge
description: A "have these converged?" condition built on the distance between two independent trackers never fires if the tracked things can't physically coincide — measure each against the state you want them to reach instead.
metadata:
  type: convention
---

The Voronoi split-screen's compositing release (`CameraManager:isCompositingActive`) waits for an eased divergence measure to reach ~0. That measure was originally the distance between the two pane cameras' centres, and each pane tracked its own player. Two real players can never occupy the same point — their colliders prevent it — so the measure had a permanent non-zero floor, and the split-screen never released in real play even though the merge decision itself was correct.

**Why:** "How far apart are these two trackers?" silently assumes the tracked things can coincide. When they track independent real-world entities with a physical minimum separation, the quantity never reaches zero, and any threshold near zero is unreachable. The bug survived a full TDD cycle because the tests that exercised release used fixtures with two objects at the *exact same point* — the one configuration where the measure does reach zero.

**How to apply:** Measure convergence against the state you actually want reached, not between the two things converging. Here each pane is compared to what it would have to be to render the shared merged view (`paneMergedViewCentre` — note it is offset from the merged camera's centre, since a pane draws its centre at its region's centroid rather than at screen centre), so the quantity is "how different does this look from just showing the merged view" and genuinely reaches zero. Same rule for the fixtures: exercise these conditions with realistic, non-overlapping inputs, never only the degenerate coincident case.
