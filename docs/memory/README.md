# Repo Memory Index

- [New test files must be added to the runner's file list](new-test-files-runner-registration.md) — a new `tests/unit/*_test.lua` or `tests/integration/*_test.lua` file silently never runs unless added to `run.lua`.
- [Entity-atomic draw & Tint](entity-atomic-draw-and-tint.md) — Tint/FlashEffect need one entity's components drawn back-to-back; don't split a draw across entities without checking this.
- [World:querySegment is unexposed](world-querysegment-unexposed.md) — bump already supports raycasting; the World wrapper only passes through AABB queries today.
- [Camera zoom range drives parallax](camera-zoom-range-drives-parallax.md) — changing how far the camera zooms out silently changes background parallax strength.
- [Split-camera merge release must converge](split-camera-merge-release-must-converge.md) — a merge/release condition built on "distance between two independent trackers" never fires if the tracked things can't physically coincide.
- [Test at the real window resolution](test-real-window-resolution.md) — camera/framing logic that mixes screenW/screenH into a threshold can encode a hidden aspect-ratio assumption; a test suite fixed at one resolution can't catch it.
