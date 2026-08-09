Status: done

# A locked door blocks everything

## What to build

- A `door` entity that can be placed in Tiled and starts locked.
- Locked means solid: a walking player, an enemy and a pushed box all stop at it.
- Door art draws 3×3 tiles of decorative bleed while the barrier stays a thin vertical strip.

## Files to create/modify

- `res/img/entity_door.png` (copy of `res/img/entity_drawbridge.png`)
- `res/snd/entity_door_open.wav`, `res/snd/entity_door_close.wav` (copies of the drawbridge pair)
- `src/entities/door.lua`
- `res/templates/door.tx`
- `tests/fixtures/door_room.lua`
- `tests/unit/door_test.lua`
- `tests/integration/door_test.lua`

## Test approach

- Unit, via `Door._internal`: `isDoorSolid` returns true only for `closed`; barrier and sprite dimensions derive from the object's width/height, not constants.
- Unit, via `tests/support/headless_bootstrap.lua`: a constructed `Door` starts in `closed` with a non-sensor barrier.
- Integration on `door_room`: walk a player into the door and assert their x stops at the barrier.
- Integration: push a box into the door and assert it stops too — no entity-type eligibility.

## Acceptance criteria

- [ ] A Tiled object of type `door` instantiates without a switch wired
- [ ] The door starts `closed` with a solid barrier
- [ ] A walking player cannot pass
- [ ] A pushed box cannot pass
- [ ] Barrier width is 25% of the object width; sprite box is 3× the object's width and height, centred

## Blocked by

Slice 01 — the exit door must vacate `res/img/entity_door.png` first.

## Gotchas

- 3× centred needs no vertical offset. The exit door lifts its sprite only because its box is 2×, which would hang the art half a tile below the ground line.
- Do **not** set `collider.walkable` on the barrier. Nothing stands on a door; `walkable` is for entity-owned colliders a player walks along.
- `Map.typeIgnores` does not need touching — `entity_factory` resolves type `door` to `src/entities/door.lua` by filename.
- Keep the file flat. ADR 0003's entity directory is for entities that genuinely need a second file, and the `_internal` seam removes the old reason to split.
- The drawbridge sprite is 4 frames at 0.3s; keep both when copying, so the animation reads at the same speed.
