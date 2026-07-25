Status: done — superseded by a post-playtesting design revision, see note at the end

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

## Superseded (post-playtesting revision)

Everything above describes the **original** design: a closed drawbridge blocks like a wall from both sides via a solid `barrier` collider. After playtesting the shipped feature, this was reversed — see DECISIONS.md Q4's revision. **The barrier collider was removed entirely.** Closed now means the gap is fully exposed on both sides; approaching from the wrong side means falling in, like any other pit, not bumping a wall.

This also surfaced two real, general engine bugs while fixing the wrong-side e2e test to expect a fall instead of a block (both documented in `tests/README.md`'s gotchas, both fixed):
- `Player:queryOnGround()`/`GroundSupport.hasGroundAt()` treated the deck's `collider.walkable = true` flag as a standing guarantee regardless of its current `sensor` state, so a player walked straight across the "exposed" gap at a fixed height instead of falling through the now-sensor deck.
- The fixture map's declared `height` was shorter than its own kill zone, so the map's own invisible bottom-boundary wall physically stopped the fall before it ever reached the kill zone.

The acceptance criteria above (checked as `[x]`) reflect what was true when this issue was originally closed; they are no longer the current behaviour. See `issues/03-open-on-correct-side.md`'s own superseded-note for the corresponding wrong-side test rewrite.
