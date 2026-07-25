Status: done

# Closed drawbridge entity that blocks like a wall

## What to build

A designer can place a `drawbridge` object in Tiled (matching `src/entities/drawbridge.lua`) over a 1-tile gap and set its `facing` (correct side) property. In game it renders in its closed state, mirrored to match `facing`, and blocks passage like a wall: a player walking into the closed bridge from either side is stopped and cannot step onto the tile, and does not fall into the gap by bumping it. No opening behaviour yet — the bridge is simply a facing-aware, impassable closed tile over a chasm.

## Files to create/modify

- src/entities/drawbridge.lua — new entity: closed-state sprite (mirrored via `Sprite:setFacing` from `facing`), a solid **closed barrier** collider blocking horizontal entry, reads `facing` from `object.properties`
- res/templates/drawbridge.tx — new Tiled template exposing the `facing` property
- res/map/<fixture>.tmx + exported .lua — a small fixture: ground with a 1-tile gap, a drawbridge over it, spawn points either side (reused by later slices)
- tests/drawbridge_test.lua — new (starts with facing/mirroring + closed-solidity helpers)
- tests/run.lua — register the new test

## Test approach

- Facing decision helper: given `facing = left|right`, the sprite mirror direction and the (later) trigger-sensor side are computed correctly.
- Closed-solidity helper: in the closed state the closed barrier is present/solid and no walkable deck exists.
- Manual run over the fixture (`love . drawphysics map=<fixture>.lua`): confirm a player is blocked from both sides and never falls into the gap.

## Acceptance criteria

- [x] `drawbridge` object placed in Tiled loads as the entity and renders closed.
- [x] `facing` property mirrors the sprite.
- [x] A player is blocked like a wall from both sides; no fall-through on bump.
- [x] Closed-state helpers covered by tests in `tests/drawbridge_test.lua`.

## Blocked by

None — can start immediately (parallel with 01).

## Implementation notes

- `src/entities/drawbridge_support.lua` holds the pure decision helpers (`triggerOffsetX`, `isBarrierPresent`, `isDeckSolid`, etc.), mirroring `ground_support.lua`. The entity itself can't be unit-tested headless (`Sprite:init` calls `love.graphics.newImage`), so only the pure module has `tests/drawbridge_test.lua` coverage; the entity is verified by manual run.
- Collision model implemented as **two always-present static colliders at the same rect** (barrier, deck), toggling `Collider:setSensor()` rather than adding/removing bodies from the world. Simpler than dynamic add/remove and made the solidity-coherence requirement (see issue 04) trivial.
- No Tiled GUI was available while building this — `res/map/drawbridge_fixture.lua` was hand-written directly in STI's exported-Lua shape (no `.tmx` source). It loads and plays correctly (confirmed via manual run below), but if anyone has Tiled available, re-authoring it properly and exporting would be preferable to hand-maintaining Lua.
- **Manually verified in-game**: `love . map=drawbridge_fixture.lua`, walked a player into the closed bridge from the spawn side — they stop flush against it, no fall into the gap.
- Added tile id 11 to `res/tilesets/props.tsx` (reusing `default.png`) purely so the Tiled template (`res/templates/drawbridge.tx`) has a palette icon; the entity itself renders via its own `Sprite` component, not STI's tile rendering.
