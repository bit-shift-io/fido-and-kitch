# Handoff: Gameplay Integration Testing

## Summary

Today's `tests/` suite only covers pure logic and small isolated modules without a `love` dependency. This feature adds a second, separate integration-test category that loads real Tiled fixture maps through the actual `Game`/`InGameState`/`Map`/`Player` stack, drives simulated keyboard and joystick input across fixed-1/60s-timestep frames the way a human would, and asserts on real gameplay state. It runs headless via a new minimal `love.*` mock (scoped only to what's actually called — confirmed by reading the STI/Sprite/Map/Player code paths), through a new separate command (`./test-integration.sh`) so the existing fast `./test.sh` loop is untouched.

The first delivery is intentionally tight: harness infrastructure, one movement test, one mechanic test (pressure switch), and a smoke test that loads every real map. Further mechanic coverage (ladders, enemies, pushables) is explicit follow-up work reusing this same harness.

## Suggested Implementation Order

1. **01-harness-foundation** — everything else depends on this. Build the `love` mock, frame stepper, `flat_ground` fixture map, and the new `test-integration.sh`/runner, proven by one trivial smoke test. The riskiest unknown here is `love.filesystem.load`'s exact contract for loading an exported map `.lua` outside LÖVE — verify against a real exported fixture early, before building anything on top.
2. **02-input-controller-and-movement-test** — `FakeInput`, `holdFor`/`runUntil`, query helpers, and the first real gameplay-behaviour test (movement, both input paths, both players).
3. **04-all-maps-load-smoke-test** — can start as soon as 01 lands; doesn't depend on 02/03. Cheap to slot in whenever convenient once the harness exists.
4. **03-pressure-switch-mechanic-test** — do last since it depends on the input/query helpers from 02, and needs its own fixture map authored in Tiled.

## Links

- [PRD.md](PRD.md)
- [DECISIONS.md](DECISIONS.md)
- [issues/01-harness-foundation.md](issues/01-harness-foundation.md)
- [issues/02-input-controller-and-movement-test.md](issues/02-input-controller-and-movement-test.md)
- [issues/03-pressure-switch-mechanic-test.md](issues/03-pressure-switch-mechanic-test.md)
- [issues/04-all-maps-load-smoke-test.md](issues/04-all-maps-load-smoke-test.md)
- No ADR was created — the mock-vs-real-LÖVE and scope decisions are logged in DECISIONS.md (Q1, Q5) rather than as an ADR, since they don't meet the full hard-to-reverse + surprising + genuine-trade-off gate (the hybrid approach explicitly keeps a path to real LÖVE open later, so it isn't a one-way door).

## Gotchas / Implementer Notes

- Verify `love.filesystem.load`'s mock behaves like `loadfile` against a real exported map `.lua` file *before* building fixture maps on top of it — this is the one load-bearing assumption flagged in DECISIONS.md that isn't yet verified against real STI output.
- Author fixture maps in the actual Tiled editor and export through the normal pipeline (same as `res/map/`) — don't hand-write the exported `.lua`, per the DECISIONS.md Q4 rationale.
- The `love.graphics`/`love.physics` mock surface was deliberately scoped down after confirming (via grep) that STI's atlas plugin and the Box2D physics plugin are unused in this codebase. If a later mechanic test needs either, that's new territory — extend the mock rather than assuming it's already covered.
- Keep `tests/integration/run.lua` structurally consistent with the existing `tests/run.lua` (`test()`/`assert*` globals, same failure-reporting format) so both suites feel like one testing convention, not two.
- `./test.sh` and `tests/run.lua` must remain completely unmodified by this feature.
