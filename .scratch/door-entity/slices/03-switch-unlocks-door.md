Status: done

# A switch unlocks and relocks the door

## What to build

- Flipping a linked switch `on` opens the door and lets players, enemies and pushables through.
- Flipping it `off` closes the door and blocks them again.
- The door animates and plays open/close sounds through the transition.

## Files to create/modify

- `src/entities/door.lua` — `Switchable` component, state machine, sound
- `res/templates/door.tx` — `target` property, matching `switch.tx`
- `tests/fixtures/door_room.lua` — add a switch wired to the door
- `tests/unit/door_test.lua`
- `tests/integration/door_test.lua`
- `tests/integration/door_sound_test.lua`

## Test approach

- Unit, pure `nextState(state, enabled, occupied)` table: `closed` + enabled → `opening`; `open` + not enabled + not occupied → `closing`; `opening`/`open` + enabled → unchanged.
- Unit: `onAnimationFinish` maps `opening` → `open` and `closing` → `closed`.
- Unit: the barrier turns sensor the frame `opening` begins, and solid only when `closing` finishes.
- Integration on `door_room`: player walks to the switch, uses it, walks through the door's tile and out the far side.
- Integration: flip the switch back and assert the player is blocked again.
- Sound: `SoundSpy`, following `tests/integration/drawbridge_sound_test.lua`.

## Acceptance criteria

- [ ] Switch `on` makes the door passable; switch `off` makes it solid again
- [ ] The barrier is passable from the frame opening starts, and solid only once closing finishes
- [ ] Open and close sounds play once per transition
- [ ] Reversing the switch mid-animation reverses the animation in place, with no frame snap
- [ ] A door with no `target` switch pointing at it stays locked forever and never errors

## Blocked by

Slice 02.

## Gotchas

- `Switchable` defaults `enabled = true`. Pass `enabled = false` explicitly or the door starts unlocked, contradicting slice 02.
- `switch.lua` resolves `object.properties.target.id` at init. The switch points at the door, not the reverse — author `door.tx` without a target and set it on the switch.
- Use `sprite:reverseFromCurrent()` when flipping an in-flight transition and `playForward`/`playReverse` for a fresh one. `drawbridge.lua`'s `checkHeld` shows both.
- `drawbridge.lua` plays `'open'` on closing and `'close'` on opening — the sound keys are swapped there. Do not copy that; wire the door's keys correctly.
- Recompute state every frame from `(switchEnabled, occupied)` rather than acting inside the `Switchable` callback. The callback only records the flag.
