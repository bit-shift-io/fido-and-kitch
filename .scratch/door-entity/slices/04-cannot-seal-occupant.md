Status: pending

# A closing door cannot seal anyone in

## What to build

- A door whose switch goes `off` while something stands in the doorway stays open instead of closing.
- A door already closing when something enters the doorway reverses back to open.
- It closes on its own the moment the doorway is clear, with the switch still `off`.

## Files to create/modify

- `src/entities/door.lua` — per-frame doorway overlap query
- `tests/unit/door_test.lua`
- `tests/integration/door_test.lua`

## Test approach

- Unit, pure state table: `open` + not enabled + occupied → unchanged; `closing` + occupied → `opening`; `closing` + clear → unchanged.
- Unit: doorway bounds cover the object's full rect, not just the thin barrier.
- Unit: the door's own colliders never count as occupants.
- Integration: stand a player in the doorway, flip the switch `off`, step many frames, assert the door is not `closed` and the player is not trapped.
- Integration: walk that player clear and assert the door then closes unprompted.

## Acceptance criteria

- [ ] A switch flipped `off` with an occupant present leaves the door passable
- [ ] An entity entering mid-close reverses the door back to opening
- [ ] The door closes once the doorway clears, with no further switch input
- [ ] Occupancy is recomputed fresh every frame — no flag survives between frames
- [ ] A permanent occupant leaves the door permanently open, with no error or thrash

## Blocked by

Slice 03.

## Gotchas

- Filter the door's own barrier out of the overlap results. `drawbridge.lua`'s `isHeld` shows the `collider.entity ~= selfEntity` check.
- The drawbridge adds `OCCUPANCY_HEIGHT_MARGIN = 32` because its deck is a floor and occupants stand *above* it. A door is already full height, so an occupant overlaps its rect directly — no margin needed. Justify it in a comment either way.
- Query the doorway rect (full object width), not the 25% barrier. An entity straddling the threshold must count.
- Reversing must use `reverseFromCurrent()`, not a replay from the end — a snap here is visible because it happens right next to the player.
