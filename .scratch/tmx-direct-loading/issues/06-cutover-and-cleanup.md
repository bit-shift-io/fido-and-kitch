Status: done

# Cut over to `.tmx` as the source of truth

## What to build

The `.tmx` files become the only map source in the project. The redundant exports are deleted, the export step is removed from the map files themselves, and everything that discovers maps by globbing for `.lua` learns about `.tmx`.

Scope for this slice:

- **Delete the six redundant exports** — `res/map/{sandbox,ll1,ll2}.lua` and `res/backgrounds/{night_forest,mushroom_cave,sky}.lua`. Their preserved copies under `tests/fixtures/golden/` stay, and the differential tests keep using them.
- **Resolve `tiny.tmx`** — it references `../generic_platformer_tiles.tsx`, which resolves to a path that does not exist (the tileset lives one directory deeper), and it is authored against Tiled 1.5.0 while every other map is 1.12.2. It has never been loadable, because enumeration only ever found exported `.lua` files and it has none. Once enumeration includes `.tmx` it becomes reachable and will hard-error. **Ask the user which they want:** repoint it at the correct tileset path, or delete it as stale scratch content. Do not leave it broken — it will break map enumeration and the all-maps test.
- **Remove the export directive** from all seven `.tmx` files — the `<editorsettings><export .../></editorsettings>` block that told Tiled where to write the `.lua`. It is now meaningless and would mislead the next author into re-exporting.
- **Level-select enumeration** — the menu's map discovery must find `.tmx` alongside `.lua`, and its display-name derivation must strip both extensions (it currently strips only `.lua`). Its empty-state message mentions "exported .lua maps" and needs updating.
- **Test map discovery** — the helpers that enumerate real maps by shelling out for `res/map/*.lua` must include `.tmx`. Both the headless all-maps load test and the rendered-screenshot all-maps test do this. **This is a false-pass risk:** a test that discovers zero maps still passes every per-map assertion, so after this change verify the tests genuinely cover all four levels rather than trusting a green run.
- **Documentation** — update `AGENTS.md` and any developer-facing notes that describe the Tiled export workflow. The "Embed tilesets" preference guidance from the preceding external-tileset work is now doubly obsolete: there is no `.lua` export at all. `CONTEXT.md` was already updated during planning.

## Files to create/modify

- `res/map/{sandbox,ll1,ll2}.lua` (delete)
- `res/backgrounds/{night_forest,mushroom_cave,sky}.lua` (delete)
- `res/map/tiny.tmx` (repoint the tileset path, or delete — user's call)
- `res/map/*.tmx`, `res/backgrounds/*.tmx` (remove the `editorsettings` export block)
- `src/ui/map_list.lua` (discover `.tmx`, strip both extensions for display, update the empty-state message)
- `tests/integration/all_maps_load_test.lua` (discover `.tmx`)
- `tests/e2e/all_maps_screenshot_test.lua` (discover `.tmx`)
- `AGENTS.md` (remove the export-workflow guidance)

## Test approach

Mostly verification of existing tests against the new content layout rather than new test code.

- Confirm the all-maps load test discovers **every** level — assert the discovered count explicitly rather than only asserting each discovered map loads, so an enumeration bug cannot pass silently.
- Confirm the rendered-screenshot all-maps test captures every level, and inspect the captures for `sandbox` in particular: the original bug drew a level with no player and raised no error, so a rendered frame is the only check that catches its return.
- Confirm the level-select menu lists all four levels plus the hand-authored `.lua` fixture map, with correct display names.
- Confirm the hand-authored `.lua` fixtures still load, since the `.lua` path must survive the cutover permanently.
- Run all three tiers.

## Acceptance criteria

- [ ] The six redundant `.lua` exports are deleted; their golden copies remain under `tests/fixtures/golden/`.
- [ ] `tiny.tmx` is either repointed at a valid tileset or deleted, per the user's decision, and does not break enumeration.
- [ ] The `editorsettings` export block is removed from all seven `.tmx` files.
- [ ] The level-select menu lists `.tmx` and `.lua` maps with correct display names, and its empty-state message no longer refers to exported `.lua` maps.
- [ ] The all-maps load test and the all-maps screenshot test both discover every level, asserted by explicit count.
- [ ] Rendered captures of every level look correct, with `sandbox` showing players and props.
- [ ] Hand-authored `.lua` fixture maps still load.
- [ ] `patches/sti.patch` is unchanged across the whole feature.
- [ ] `AGENTS.md` no longer describes a Tiled export step.
- [ ] `./test-all.sh` passes, with the pre-existing camera-convergence failure the only exception.

## Implementer notes

- **Check git status before deleting anything.** The exports are tracked content; make sure the golden copies from issue 01 are committed or at least present before removing the originals.
- There is a known pre-existing unit-test failure — a camera-convergence assertion — unrelated to this feature and failing identically on an unmodified tree. Do not attempt to fix it here; just confirm it is the only failure.
- The menu's map directory is configured where the menu state is constructed, and it derives display names by stripping the extension — both need the `.tmx` case.
- Both all-maps tests enumerate by shelling out with a glob. Extending the glob to two extensions is easy to get subtly wrong in a way that silently returns fewer files, which is exactly why the acceptance criteria demand an explicit count assertion.
- After this slice the project has no derived map artefacts. Worth stating plainly in `AGENTS.md`: edit in Tiled, save, run — there is no export step.

## Blocked by

01, 02, 03, 04, 05
