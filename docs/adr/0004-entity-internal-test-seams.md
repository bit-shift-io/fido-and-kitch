# ADR 0004: Entity `_internal` white-box test seams for headless unit tests

**Status:** Accepted
**Date:** 2026-08-30

## Context
Several entities (drawbridge, pressure_switch, blocker, mover_platform,
replicator, story) reach a point where a headless unit test wants to pin
down a pure decision — a state flip, a path advance, an emit point — without
driving the whole physics/world/render stack that the entity drags in at
load time. Without a seam, those decision helpers either leak out as public
API or force a full-stack integration test for what is really pure logic.

## Decision
An entity may expose its private decision helpers and pure-logic functions
through a **`_internal` table attached to the class** (e.g.
`Drawbridge._internal`, `PressureSwitch._internal`, `MoverPlatform._internal`).
This is an explicit white-box seam: `_internal` exists so the entity's own
test file can construct a real entity (see ADR 0005) or call pure functions
headless and assert on them. It is not part of the public gameplay API —
consumer code must not call into `_internal`.

## Alternatives Considered
- **Split the pure logic into a `_support.lua` sibling** (ADR 0003 style) —
  worked for `pushable_support`/`ground_support` because those decisions are
  genuinely shared across entities. Rejected as a general rule once
  headless_bootstrap (ADR 0005) made a real entity constructible: splitting
  an entity's own logic into a second file purely to make it unit-testable
  was the wrong coupling (see ADR 0005).
- **Full-stack integration tests only** — always boot the entity in the real
  harness. Rejected for the fine-grained decisions: too heavy, and it buries
  a one-line pure rule under a multi-hundred-line test.

## Consequences
- Pure decisions stay private where they belong (reachable only via the
  `_internal` seam) instead of leaking onto the public instance API.
- Unit tests can assert exact behaviour headless and fast.
- `_internal` needs a documented convention so it is not mistaken for a
  public surface.
