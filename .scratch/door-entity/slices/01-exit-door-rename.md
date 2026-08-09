Status: done

# Exit door renamed uniformly

## What to build

- Every exit-door asset and Tiled object name reads `exit_door`, with no `exit`/`door` shorthand left.
- `res/img/entity_door.png` is free for the new door entity to claim.
- The exit door plays a real open sound instead of warning about a missing file.

## Files to create/modify

- `res/img/entity_door.png` → `res/img/entity_exit_door.png` (`git mv`)
- `res/snd/entity_exit_door_open.wav` (copy of `res/snd/entity_drawbridge_open.wav`)
- `res/templates/exit.tx` → `res/templates/exit_door.tx` (`git mv`); object `name` → `exit_door`
- `src/entities/exit_door.lua` — image path; delete the "no asset yet" comment
- `res/map/sandbox.tmx`, `res/map/fab1.tmx` — template path + object name
- `res/map/ll1.tmx`, `res/map/ll2.tmx`, `res/map/lurid_2p_01.tmx` — object name
- `tools/level_generator/main.lua` — `exitObject`'s `template` and `name`
- `tests/unit/level_generator_tmx_writer_test.lua`, `tests/unit/level_generator_main_test.lua` — expected template path and object name
- `tests/integration/tmx_golden_test.lua` — normalisation entry for the renamed objects

## Test approach

- Existing suites carry this slice: `all_maps_load_test`, `tmx_golden_test`, `exit_door_sound_test`, the level-generator unit and integration tests.
- `exit_door_sound_test` currently passes against a missing file (`Sound:play` warns and skips); confirm it still passes now the file exists and actually loads.
- Grep the whole tree for `entity_door.png`, `exit.tx` and `name="exit"` and confirm no stragglers.
- Run `./run.sh map=ll1` and check the exit door still draws.

## Acceptance criteria

- [ ] No reference to `res/img/entity_door.png` or `res/templates/exit.tx` remains
- [ ] All five maps name their exit-door object `exit_door`
- [ ] The exit door plays an audible sound on open
- [ ] `./test-unit.sh` and `./test-integration.sh` pass

## Blocked by

None — can start immediately.

## Gotchas

- `res/img/entity_door.png` already exists and is the *exit* door's art. Move it before anything copies over that name.
- `tmx_golden_test.lua` diffs `sandbox`, `ll1` and `ll2` against committed Tiled exports. Renaming an object's `name` will fail the diff. Do **not** edit the golden `.lua` files — they are genuine Tiled exports and their authenticity is the test's whole point. Add a documented normalisation entry in the file's numbered header list instead, naming the object, the field and the cause, matching entries 4 and 5.
- `ll1.tmx` also contains `target:exitThroughDoor(entity)` in NPC `finish` properties. That is a method call, not a name to rename — leave it.
- Sound assets are `.wav`; copy the file, don't symlink.
