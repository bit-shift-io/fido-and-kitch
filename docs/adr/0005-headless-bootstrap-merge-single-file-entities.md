# ADR 0005: headless_bootstrap lets multi-file entities merge back into one file

**Status:** Accepted
**Date:** 2026-08-30

## Context
`tests/support/headless_bootstrap.lua` was introduced to construct a **real
entity in the unit tier** — boots the globals and lõve/graphics mocks needed
to `require` and `new()` an actual entity class, where previously
`tests/unit/` could not load entity modules (they build `Sprite`/`Collider`
and other heavy machinery at require time).

## Decision
With a real entity constructible headless, entities whose pure decision
helpers had been split out into a separate `_support.lua` sibling purely to
dodge headless construction are **merged back into their single entity
file** — e.g. `src/entities/drawbridge.lua` and
`src/entities/pressure_switch.lua` — keeping those helpers as private locals
reached through the entity's `_internal` test seam (ADR 0004). Named-scale
splits remain for logic that is genuinely shared across multiple entities
(`src/components/pushable/pushable_support.lua`,
`src/player/ground_support.lua`), which are components, not one entity's own
logic.

## Alternatives Considered
- **Keep the split** — leave drawbridge/pressure_switch as init + `_support`
  pairs. Rejected: the split existed only to satisfy a headless-loading
  limitation that no longer exists; it spread a single entity's logic across
  files and forced duplicate "mirror the sibling" test setups
  (`pressure_switch_test.lua` "mirroring drawbridge_test.lua's split").
- **No headless unit coverage** — fall back to integration-only testing.
  Rejected: the whole point of headless_bootstrap is to keep entity logic
  unit-testable, letting tests like `coin_identity_test.lua` construct a real
  Coin through headless_bootstrap.

## Consequences
- `drawbridge.lua`, `pressure_switch.lua` (and `blocker.lua`, which follows
  the same single-file + `_internal` pattern) hold their decision helpers
  privately, reachable only via `_internal`.
- New multi-file entity splits are reserved for shared logic; an entity's
  own logic stays in its single file unless genuinely shared.
- Coin/pressure-switch unit tests construct a real entity through
  headless_bootstrap rather than duplicating helpers.
