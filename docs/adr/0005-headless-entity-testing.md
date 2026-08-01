# ADR 0005: A headless bootstrap makes full entities constructible in tests/unit/, so the drawbridge's file split is reversed

**Status:** Accepted
**Date:** 2026-08-01

## Context

ADR 0003 gave the drawbridge (and later pushable, pressure_switch) a directory with two files: `drawbridge.lua` (the `Class{__includes = Entity}`, composing `Sprite`/`Collider`/`Sound`) and `drawbridge_support.lua` (the pure decision helpers — `nextStateOnHeldChange`, `isHeld`, etc. — with no LÖVE surface). The split existed for exactly one reason: `tests/unit/` is pure Lua with no `love` global at all, and constructing a `Drawbridge` crashed there, so only the extracted pure functions could be tested at that tier.

Two things made that crash unnecessary rather than fundamental:

- `Sprite:init` indexed the image `AssetManager.getImage` already returns as `nil` headless (by design — see `Sound.silentMode`'s precedent). This was one guard away from working, not a real LÖVE dependency. Fixed in `src/components/sprite.lua`: `framesFromSheet` now returns placeholder frame entries (count-correct, so `Timeline:getFrameIndex(#frames)` still has real animation state to index into) instead of crashing when there's no texture to cut into `Quad`s, and `fitToShapeArguments` is skipped rather than indexing a nil image.
- The bump physics backend (`src/physics/bump/`) has no `love.*` calls outside its own `draw`/`worldDraw` methods, which a headless test never calls. `tests/unit/kill_zone_test.lua` and `ground_support_test.lua` already relied on this, constructing a real `World`/`Collider` headless.

What was actually missing was narrower still: the class globals `src/main.lua` wires for the real game (`Class`, `Vector`, `Entity`, `Sprite`, `Collider`, `Sound`, `Tween`, `Timeline`, ...) and a `world` instance, none of which `tests/unit/` set up beyond the ad hoc `Class = Class or require(...)` a couple of files did for their own narrower needs.

## Decision

Add `tests/support/headless_bootstrap.lua`, required by any unit test that needs to construct a real entity: it wires the class globals (idempotently, matching the existing `X = X or require(...)` convention) and exposes `HeadlessBootstrap.resetWorld()` for a fresh `world` per test.

With that in place, `src/entities/drawbridge/{drawbridge.lua,drawbridge_support.lua}` is merged back into a single flat `src/entities/drawbridge.lua`. The pure decision helpers stay as private locals (nothing outside the file called them through the module boundary anyway); a `Drawbridge._internal` table exposes them for `tests/unit/drawbridge_test.lua` only, documented in-file as a white-box test seam, not production API. That file now has two tiers of coverage: the original pure-helper tests (unchanged, now via `_internal`) plus new entity-level tests that construct a real `Drawbridge` — real `Sprite`, real `Collider`, a real bump `World` — and drive it through `Drawbridge:update(dt)`, verifying wiring the pure-function tests structurally couldn't (deck sensor flips, sound calls on transition, `onAnimationFinish` dispatch) without needing the full `Game`/`Map` stack `tests/integration/` and `tests/e2e/` already cover for the spatial/game-level scenarios.

## Alternatives Considered

**Dependency-inject `world` and the component classes into the entity.** E.g. `Collider{world = props.world or world}`, or a factory passing component constructors in. Rejected for the drawbridge specifically: the real headless-constructible `World` (see above) means there's no seam actually worth injecting — a stub `world` would just be extra surface to keep honest for no behavioral gain over the real thing. Threading component classes through every entity constructor to satisfy a testing concern that a shared bootstrap already resolves would spread ceremony across every entity for a problem that's global (missing globals), not per-entity.

**Leave the split in place.** Rejected: once construction works headless, the split's only remaining effect is spreading one entity's logic and its tests across two files/two directories for no reason — the exact "naming coincidence rather than a structure" ADR 0003 itself objected to, just inverted.

## Consequences

- Any entity can now get real entity-level unit tests (construction, state wiring, component interaction) without a `Game`/`Map`/`World` bootstrap, by requiring `tests/support/headless_bootstrap.lua`. This is not retrofitted onto every existing entity test in this change — only drawbridge's.
- `Sprite` is now headless-safe in the same sense `Sound` already was (`isHeadless()`, mirroring `Sound.silentMode`). Any other component relying on `love.graphics`/`love.audio` should follow the same pattern if it needs headless construction.
- ADR 0003's directory convention is unchanged for entities that still need it (multiple files for reasons other than headless testability, or entities not yet revisited). Only the drawbridge's own split is reversed here.
- `world` is a singleton-shaped instance (colliders live on it, not the module), so `HeadlessBootstrap.resetWorld()` must be called per test, not once — reusing one `world` across tests leaks colliders from a previous test into the next query, exactly the trap `World:new(0, 0, true)` already avoided ad hoc in `kill_zone_test.lua`/`ground_support_test.lua`.
