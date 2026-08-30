# Fix audit findings (AUDIT.md 2026-08-30)

Plan to resolve the issues surfaced in the 2026-08-30 audit. Each task touches
at most 1–2 files so it can be executed and verified independently. Run
`./test-unit.sh` / `./test-integration.sh` after each phase; re-verify
`./test-e2e.sh` after anything touching rendering/physics. Mark items `[x]` as
they land. Task ordering favours the highest-risk items first.

## Phase 1 — Dead/broken code (High)

- [x] `src/physics/bump/collider.lua` — remove the broken nil assignment
  `self.draw = Collider.collider_draw`. NOTE (verified): `setFixedRotation`
  and `teleport` are NOT dead — both are called internally (`setFixedRotation`
  at init lines 36/40; `teleport` from `setX`/`setY`), so they were kept.
- [x] `src/physics/bump/world.lua` — remove dead `World:draw` method (calls
  `Collider:worldDraw` which is itself dead; debug rendering is via
  `DebugOverlay`). Kept `queryRects` bookkeeping — `DebugOverlay` still reads
  it.
- [x] `src/physics/bump/collider.lua` — remove `worldDraw` (its only caller
  `World:draw` was removed).
- [x] `src/player/player_movement.lua` — deleted dead `decideLadderMovement`
  (zero callers; `LadderState` implements climb inline).
- [x] `src/entities/exit_door.lua` — deleted dead methods `reset` and `add`;
  kept `subtract` (test-only but referenced by integration tests).
- [x] `src/input/input_config.lua` — deleted the dead `save()`/`serialize()`
  chain (never called; config is only ever loaded) + unused `Log` require.
- [x] `src/npc/npc_config.lua` — removed `BehaviorTypes` and never-read
  default fields (`followTarget`, `canPush`, `canBePushed`, `pushForce`,
  `triggerSwitches`, plus dead `deceleration`/`patrolPoints`).
- [x] `src/map/tmj.lua` — deleted unused local function `embeddedKeySig`.
- [x] `src/components/timeline.lua` — removed unused local `startClock`.
- [x] `src/utils/asset_manager.lua` — KEPT `clear()`/`getTextureCount()`:
  documented public API in AGENTS.md (idempotent, trivial); no change.
- [x] `src/utils/tbl.lua`, `tests/unit/replicator_test.lua` — moved `tbl.length`
  into the replicator test as a local `count()` helper; removed the export.
- [x] `src/npc/npc_spider.lua` — removed the unused `NPCConfig` require.
- [x] `src/fx/manager.lua` — confirmed the existing comment (lines 57–59)
  explaining why game code uses `getActive()` instead of `draw()` is accurate;
  no change needed.
- [x] Deleted orphaned debug script `tests/integration/debug_switch_drawbridge.lua`
  (raw `print` scaffolding, not registered anywhere).
- [x] Deleted the 3 unreferenced fixtures: `tests/fixtures/ladder_room.tmj`,
  `tests/fixtures/ladder_walkin_repro.tmj`, `tests/fixtures/npc_follow_test.tmj`.
  (Verified zero references in src/tests/tools.)
- [x] Fixed `tests/unit/teleport_travel_state_test.lua` call signature to
  `enter(prevState, params)`.
- [x] Fixed `tests/unit/template_sprite_props_test.lua` flag spriteOffsetY
  assertion value from 0 -> 2 (actual).

## Phase 2 — Fix the stale mover_platform numbers (High)

- [x] `src/entities/mover_platform.lua` — update the stale `100px/s` comments
  (lines 12, 105) to the real default (50) and fix the
  `pauseDistance = (pause or 0) * (speed or 100)` fallback (line 115) to agree
  with the real default (50) at line 236.

## Phase 3 — De-duplicate NPC defaults (Medium-High)

- [x] `src/npc/npc_config.lua`, `src/entities/npc_{bird,spider,rabbit,robot}.lua`
  — collapsed the per-NPC hand-rolled defaults tables + manual merge loops into
  `NPCConfig.Defaults`. Kept only genuinely-per-NPC fields (`idleImage`,
  `width`, `height`). Added unit test `tests/unit/npc_config_test.lua` (4 tests).
- [x] `src/entities/npc_spider.lua` — removed the unused `NPCConfig` require.

## Phase 4 — Extract IPC handler duplication (Medium)

- [x] `src/ipc/handlers/{debug,entity,map,player}.lua` — extract the duplicated
  `inGameState()` helper and `stepFixed()`/`FRAME_DT` loop into a new shared
  `src/ipc/handler_helpers.lua` (or reuse an existing util) and have all four
  handlers require it. Run integration tests exercising each IPC command.

## Phase 5 — Register / reconcile unregistered tests (Medium)

- [x] `tests/unit/run.lua` — added 5 unregistered unit files:
  `mesh_ribbon_emitter_test.lua`, `mesh_ribbon_render_test.lua`,
  `state_machine_trytransition_test.lua`, `teleport_trail_test.lua`,
  `teleport_travel_state_test.lua`, plus new `npc_config_test.lua`.
- [x] `tests/integration/run.lua` — added `level_layer_render_test.lua` to
  `defaultTestFiles`; moved `ladder_catch_test.lua` and `teleport_clear_test.lua`
  into registration; `ladder_catch_test.lua` vs `ladder_catch_slide_test.lua`
  are distinct (kept both); `teleport_clear_test.lua` vs
  `switchable_teleport_test.lua` distinct (kept both).

## Phase 6 — Resolve missing-doc drift (Medium)

- [ ] Author `DECISIONS.md` capturing the decisions referenced across ~35
  files (pushable/blocker/drawbridge/teleport/template/tests/tools), OR remove
  the `DECISIONS.md Q#` references from those files and replace with inline
  notes. Prefer authoring the doc; cross-check every referenced Q number.
- [ ] `docs/adr/` — add ADRs 0002–0005 (or correct the `ADR 0005` references
  in `pushable_support.lua`, `blocker.lua`, and the coin/pressure_switch
  tests) so cited ADRs exist.
- [ ] Restore or re-point the 5 `NOTES.md 2026-08-24` references
  (`player_movement.lua:133`, `ladder_catch_test.lua:4`, `ladder_seam_test.lua:6`,
  `ladder_top_test.lua:3`, `npc_ladder_test.lua:1) — either find or write the
  missing notes, or strip the cross-references.

## Phase 7 — Minor polish (Low)

- [ ] Fix `pickup.lua:18` typo `annother` -> `another`.
- [ ] Fix `ARCHITECTURE.md:230-233` "Adding a New Player State" guide (player
  states now per-file in `src/player/states/`, not a single table).
- [ ] Remove/replace `tests/integration/run.lua:3` reference to non-existent
  `.scratch/integration-testing/` comment.
- [ ] Remove stale `AGENTS.md:65` list of deleted fx presets (`dust_burst.lua`,
  `spark_trail.lua`) or update to reflect current `src/fx/` presets.
- [ ] Update AGENTS.md layout section (currently missing `src/npc/`, `src/ipc/`,
  `src/emitters/`, `src/player/states/`, `src/utils/level_records.lua`).

## Phase 8 — Named constants (Low)

- [ ] `src/player/player_sensors.lua`, `src/player/ground_support.lua` — extract
  repeated probe/margin numeric literals (`+4`, `-4`, `or 4`, `or 5`) into
  named constants (e.g., `PLAYER_PROBE_MARGIN = 4`).
- [ ] `src/entities/mover_platform.lua`, `src/entities/jump_pad.lua` — replace
  inline default literals (`speed = 50`, `pause = 0.5`, `count = 16`,
  `speed = 120`) with named constants.
- [ ] `src/map/init.lua`, `src/map/tmj.lua`, `src/map/tj_template.lua`,
  `src/map/tj_tileset.lua` — extract the shared `readFile` fallback into a
  utility (`src.utils/file.lua`).
- [ ] `src/camera.lua` — extract `local clamp = function(v, lo, hi)` into
  `src.utils/number.lua`.

## Phase 9 — Packaging + tests (Low)

- [ ] Fix `makelove.toml` shallow globs (`./src/*`, `./res/*`, `./lib/*`) to be
  recursive (`./src/**/*.lua`, `./res/**/*.tmj`, `./lib/**/*.lua`) to include
  nested directories.
- [ ] Decide fate of unused library payload: `lib/Slab/` (only initialized once),
  `lib/hump/{camera,gamestate,signal,timer,vector-light}.lua` (none required by src or tests). Consider shipping or dropping.
- [ ] Run `./test-all.sh` to verify all three test tiers pass after changes.
