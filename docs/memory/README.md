# Repo Memory Index

- [New test files must be added to the runner's file list](new-test-files-runner-registration.md) — a new `tests/unit/*_test.lua` or `tests/integration/*_test.lua` file silently never runs unless added to `run.lua`.
- [Entity-atomic draw & Tint](entity-atomic-draw-and-tint.md) — Tint/FlashEffect need one entity's components drawn back-to-back; don't split a draw across entities without checking this.
- [World:querySegment is unexposed](world-querysegment-unexposed.md) — bump already supports raycasting; the World wrapper only passes through AABB queries today.
