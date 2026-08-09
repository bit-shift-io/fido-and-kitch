# PLAN - Ladder Props (per-rung tile objects) + real off toggle

Convert ladders from top-anchored tall rects to per-rung bottom-anchored gid
tile objects (props) that render in Tiled, auto-merge into one logical ladder,
and gain a real switch on/off (hide + disable climb). See `NOTES.md` for the
grilled decisions.

Each task touches at most 1-2 files. Run `./test-unit.sh` after tasks touching
logic, `./test-integration.sh` after map/entity behavior changes.

- [x] 1. New pure module `src/map/ladder_merger.lua`: given a layer's rung objects with `x,y,width,height` and custom-property sets, group rungs sharing a column (same x), vertically contiguous (one's top == next's bottom), and having identical custom properties; return each group's merged bottom-anchored rect (bottom=max rung, top=min rung, height=top-bottom) plus member rungs. Headless-safe, no World/I/O.
- [x] 2. Add `tests/unit/ladder_merge_test.lua` covering:  merge contiguous stack, split on gap, split on custom property difference, single rung, two columns, unusual heights (ll2 19px drift).
- [x] 3. `src/map/entity_factory.lua`: pre-pass over ladder-typed objects before entity loading that runs `ladder_merger` per layer and annotates each rung object with its family rect + `leadRung` flag (lowest rung is lead). No behavior change yet.
- [x] 4. `src/entities/ladder.lua`: lead rung builds one merged Ladder (single static sensor from the union bottom-centered rect, sprite stack from `res/img/ladder.png`); non-lead rungs become thin aliases exposing `isLadder=true`, shared `.rect` and pointer to lead; store logical rect in bottom-anchored form and update `resizeTileHeight(n,'top')`/`grow` to move the top edge (bottom fixed).
- [x] 5. `src/entities/ladder.lua`: extend `Ladder:switch` to handle `switch.state=='off'` - remove collider + sprites (logical rect unchanged) so climbing stops; restore everything on `on` keeping any grown height. Keep existing `switchOn` exec path.
- [x] 6. Add integration-style unit coverage in `tests/unit/ladder_toggle_test.lua` (or extend existing ladder test): hiding while a player overlaps falls through to `FallState` via `shouldFallOffLadder` (`src/player/player_states.lua:73`) without engine changes.
- [x] 7. Migrate `res/map/ll2.tmx`: replace tall rect ladder objects with stacked per-tile gid objects (template-compatible, bottom-anchored), move the `switchOn` `entity:grow(5)` property to the top rung so it stays balanced; verify switch target id 9 still resolves to the merged ladder.
- [x] 8. Migrate `res/map/ll1.tmx` to per-rung objects and drop layer-level `properties.ladder` there; verify no double sensor volume (see `createLadderVolumes` path in `src/map/init.lua:94`).
- [x] 9. Migrate `res/map/lurid_2p_01.tmx` to per-rung objects and drop its layer `ladder` property.
- [x] 10. Migrate `res/map/sandbox.tmx` and `res/map/fab1.tmx` to per-rung objects (keep their layer `ladder=false` semantics unchanged).
- [x] 11. Migrate fixture exports `tests/fixtures/ladder_platform_room.lua` and `tests/fixtures/ladder_platform_top_exit_room.lua` to per-rung gid objects (bottom-anchored) and run an integration climb test against them.
- [x] 12. `tools/level_generator/main.lua`: emit per-rung gid ladder objects (tile per unit of ladder height, bottom-anchored) instead of a single gid-less rect; update generator expectations/tests in the same task.
- [x] 13. Cleanup: reconcile `src/map/init.lua` `createLadderVolumes` + `layer.properties.ladder` usage with the entity-only model; audit `src/ipc/game_api.lua:342` (GET_TILE_GRID ladder marking) for the new gid-based format.
- [x] 14. Final: `./test-unit.sh` and `./test-integration.sh` green (437 unit / 95+7 integration, the 7 being known pre-existing baseline failures); ll2 smoke-check: switch grows the merged ladder 3→8 tiles, switch off hides it (collider/sprites removed) while keeping the grown height.