# Codebase Audit Summary

**Audit Target:** `fido-and-kitch` (LÖVE 2D puzzle-platformer)  
**Date:** 2026-08-30  

---

## Executive Summary

Well-organized LÖVE 2D codebase with clean component architecture, strong three-tier test suite, and zero TODO/FIXME tags in first-party code. The strongest areas are sound entity/module boundaries (player, map, states, diorama), a mature test harness with `_internal` white-box seams, and consistent lint-free source. Primary technical debt is duplication and drift: copy-pasted IPC handler helpers, per-NPC defaults tables that duplicate `npc_config.lua`, ~14 hand-rolled entity init blocks, a broken `collider_draw` nil assignment, and a package risk from `makelove.toml`'s shallow globs. A meaningful fraction of the test suite (8 unit/integration test files) is written but never registered in the runners, silently dropping coverage.

## Key Metrics

- **Unused/Orphan Files:** 2 first-party (`tests/integration/debug_switch_drawbridge.lua`, `src/export_png.lua` tooling); 3 unreferenced fixtures; `lib/Slab/` + several `lib/hump/` modules shipped but unused
- **Dead Functions/Methods:** ~14 fully-dead (zero callers) + ~6 referenced only by tests; 1 broken nil assignment
- **Commented-Out Code / Debug Logs:** 0 commented-out blocks in `src/`/`tests/`; ~18 level-gated `Log.debug` calls (acceptable); 1 orphaned debug script with raw `print`s
- **Open TODOs/FIXMEs:** 0 in first-party code; TODOs only in vendored `lib/`; 5 tracked in `TODO.md`
- **Unregistered Test Files:** 8 (5 unit, 3 integration) never run by default suite

---

## Findings & Recommendations

### 1. Unused Files & Dead Code

| File Path | Type | Details | Recommended Action |
| :--- | :--- | :--- | :--- |
| `tests/integration/debug_switch_drawbridge.lua` | Orphaned debug script | Full of ad-hoc `print("Bridge:", bridge)` instrumentation; not registered in `run.lua`, required nowhere | Delete (dev scaffolding) |
| `tests/fixtures/ladder_room.tmj` | Orphaned fixture | No test/map references | Delete or wire to a regression test |
| `tests/fixtures/ladder_walkin_repro.tmj` | Orphaned fixture | No test/map references | Delete or wire |
| `tests/fixtures/npc_follow_test.tmj` | Orphaned fixture | `npc/states/follow_state.lua` exists but nothing exercises it with this fixture | Wire to a test or delete |
| `src/player/player_movement.lua:28` | Dead function | `PlayerMovement.decideLadderMovement` — zero callers, never tested; `LadderState` implements climb inline | Delete |
| `src/physics/bump/collider.lua:80` | Broken nil assignment | `self.draw = Collider.collider_draw` but `collider_draw` is never defined anywhere → assigns `nil` | Remove the line (or define the fn) |
| `src/physics/bump/world.lua:16` + `collider.lua:121` | Dead draw path | `World:draw` → `Collider:worldDraw` never called (debug physics via `DebugOverlay` instead) | Delete both |
| `src/physics/bump/collider.lua:153,158,169` | Dead methods | `setFixedRotation`, `teleport` (no callers); `setY` used only internally | Delete `setFixedRotation`/`teleport` |
| `src/utils/asset_manager.lua:14,18` | Dead exports | `clear()`, `getTextureCount()` — zero refs (but documented in AGENTS.md) | Delete or keep + keep doc in sync |
| `src/entities/exit_door.lua:78,82,86` | Dead methods | `reset`, `add`, `subtract` — `reset`/`add` zero callers; `subtract` test-only | Delete `reset`/`add` (or keep `subtract` as test API) |
| `src/input/input_config.lua:38,75` | Dead chain | `save()` + `serialize()` never called (config never persisted from game) | Delete or add persistence path |
| `src/npc/npc_config.lua:4-11,22-27` | Dead data | `BehaviorTypes` table + several default fields (`followTarget`, `canPush`, `canBePushed`, `pushForce`, `triggerSwitches`) never read | Trim dead fields |
| `src/entities/npc_spider.lua:4` | Unused require | `local NPCConfig = require(...)` never used | Remove |
| `src/components/timeline.lua:98` | Unused local | `local startClock = self.tween.clock` assigned, never read | Remove |
| `src/map/tmj.lua:171` | Unused local fn | `embeddedKeySig(key)` never called | Delete |
| `src/utils/tbl.lua:34` | Test-only | `tbl.length` only used by `tests/unit/replicator_test.lua` | Keep as test helper or move |
| `src/components/timeline.lua:204-212` | Test-only | `setDirection`/`setSpeed`/`getSpeed` used only by `timeline_reverse_test.lua` | Keep as test API |
| `src/fx/manager.lua:51` | Deliberately unused | `FxManager:draw` — code avoids calling it (would double-draw) | Keep + comment documents this |
| `lib/Slab/` (whole dir) | Unused vendored payload | Required once at `main.lua:46`, invoked once at `:135`; menu is custom-drawn | Remove or replace with own menu (verify packaging) |
| `lib/hump/{camera,gamestate,signal,timer,vector-light}.lua` | Unused vendored payload | Only `hump.class` + `hump.vector` are used | Trim vendored deps |
| `tests/support/capture.lua:20`, `fake_input.lua:55,135`, `queries.lua:57`, `love_mock.lua:23,223` | Dead test helpers | `Capture.clearContext`, `Joystick:setButtonDown`, `WindowControl:toggleFullscreen`, `Queries.inventoryCount`, `data:mapPixel`, `mesh:setVertices/getVertices` — no callers | Delete or document as planned API |
| `src/entities/boulder.lua`, `layered_prop.lua`, `npc_rabbit.lua`, `npc_bird.lua`, `pressure_switch.lua` | Reachable but only via fixtures/templates/tests | No authored Tiled object in any shipped map | Not orphans — note as untested-by-authored-content |

### 2. Code Structure & Complexity Smells

| File Path | Issue | Context / Severity | Suggested Refactor |
| :--- | :--- | :--- | :--- |
| `src/ipc/handlers/{debug,entity,map,player}.lua` | Duplication (High) | `inGameState()` helper + `local stepFixed`/`FRAME_DT` loop copy-pasted verbatim across all 4 handlers | Extract a shared `src/ipc/handler_helpers.lua` |
| `src/entities/npc_{bird,spider,rabbit,robot}.lua` | Duplication (High) | Each hand-rolls a full defaults table (overlapping keys) + the same `merge` loop, duplicating `npc_config.lua`'s `NPCConfig.Defaults` | Collapse per-NPC tables into `NPCConfig`; only `idleImage`/`width`/`height` differ |
| `src/entities/…` (~14 direct `Entity` subclasses) | Duplication (Medium-High) | Same `Rect.centreOfMapObject` + `SpriteProps.fromObject` + `addComponent(Sprite/Collider)` init boilerplate recurs across cage, flag, exit_door, jump_pad, kill_zone, ladder, mover_platform, pressure_switch, replicator, story, switch, teleport, drawbridge, blocker, layered_prop | Extract a shared solid-static-entity init helper (factory already exists for coin/key/pushbox) |
| `src/map/init.lua:21` / `tj_template.lua:31` / `tj_tileset.lua:20` / `tmj.lua:463` | Duplication (Medium) | Identical `io.open → read('*a') → close` file-reading fallback in 4 places | Centralize into one `readFile` module |
| `src/camera.lua` / `src/map/parallax_renderer.lua` | Duplication (Low) | `local function clamp` defined in both | Share from `utils` |
| `src/map/tmj.lua` | File length 613 | Largest file; mixed parsing + embedded-tile + template concerns | Consider splitting parse helpers |
| `src/npc/npc_base.lua` | File length 479 | Core NPC logic + states + utility AI | Consider extracting utility-weight AI |
| `src/entities/story.lua` | File length 418 | Entity + dialog/bubble rendering | Consider splitting render helpers |
| `src/ipc/command_handlers.lua:30-191` | Function length 121 | `registerBuiltins` — ~20 closures, player-index `if not idx or (idx~=1 and idx~=2)` + action validation repeated ~6× | Extract a small validator helper |
| `src/entities/drawbridge.lua:134-237` | Function length 104 | `Drawbridge:init` monolithic | Split into sub-init helpers |
| `src/player/player.lua:43-127` | Function length 85 | `Player:init` | Consider composing subsystems |
| `src/ui/map_card.lua` | Nesting depth 9 | Deeply nested read/parse helpers | Extract sub-functions |
| `src/map/entity_factory.lua`, `src/map/init.lua`, `src/map/tmj.lua`, `src/map/tj_tileset.lua` | Nesting depth 7 | Render-order / object-exec substitution loops | Extract inner helpers |
| `src/export_png.lua` | Nesting depth 8 + tool in `src/` | Dev tool living among game code | Move to `tools/` |
| `src/ui/grid_overlay.lua:22` / `src/export_png.lua:73` | 9 / 8 params | `GridOverlay.drawGrid(mapW,mapH,tx,ty,sx,sy,screenW,screenH,tile)`; `paintRect(...8)` | Group into options/rect table |
| `src/map/tmj.lua:360` | 8 params | `Tmj.parseLayer(...)` | Group helpers into a parse-context table |
| `src/player/player_sensors.lua`, `src/player/ground_support.lua` | Magic numbers | Repeated `4`/`5` inward margins + probe offsets (≈10 sites); `x±2`/`+4`/`+5` probes un-named (codebase already centralizes these into `movement_constants.lua`/`physics_tolerance.lua`) | Name the probe/margin constants |
| `src/entities/mover_platform.lua:236-238` | Magic numbers + stale | Inline `or 50`/`or 0.5` fallbacks for template defaults | Name constants |
| `src/entities/jump_pad.lua:56,74` | Magic numbers | `count=16`, `speed=120` inline | Name constants |
| `src/npc/npc_base.lua:46-54,85` | Magic numbers | `utilityWeights` hardcoded; `RESPAWN_DELAY = 2` inline | Name constants |
| `src/ipc/handlers/debug.lua:60` | Missing error handling | Screenshot path `/working_dir/filename.png` built without verifying parent/extension | Validate before write |
| `src/components/variable.lua:25` | Fragile event wiring | `'on_'..value` string-built event name can silently emit to nothing | Check signal exists |

### 3. Comments & Technical Debt

| File Path | Type | Snippet / Context | Recommendation |
| :--- | :--- | :--- | :--- |
| `src/entities/mover_platform.lua:12,105,115` | Stale comment + code (High) | Comments built on old `100px/s` default; `pauseDistance = (pause or 0) * (speed or 100)` disagrees with `or 50` at line 236 (default is 50). Explicitly flagged as known-stale in `NOTES.md` | Update to 50/0.5 (align fallback with template) |
| `DECISIONS.md` | Missing doc referenced from **35 files** | `src/main.lua`, pushable, blocker, drawbridge, teleport, tj_template, level_records, tests/support, tools/… all cite `DECISIONS.md Q#` but file doesn't exist | Ship the decision doc or strip/repoint refs |
| `docs/adr/` | Missing ADRs | Only `0001` exists, but `pushable_support.lua`, `blocker.lua`, `coin_identity_test`, `pressure_switch_test` cite `ADR 0005` | Add ADRs 0002–0005 or correct refs |
| `NOTES.md 2026-08-24` | Dangling refs | `player_movement.lua:133`, `ladder_catch_test.lua:4`, `ladder_seam_test.lua:6`, `ladder_top_test.lua:3`, `npc_ladder_test.lua:1` cite ladder notes no longer in `NOTES.md` (only 2026-08-29 remains) | Restore notes or re-point |
| `ARCHITECTURE.md:230-233` | Stale how-to | "Adding a New Player State" describes a `PlayerStates` table; real states are per-file in `src/player/states/` | Update the guide |
| `AGENTS.md:65` | Stale listing | Lists `src/fx/dust_burst.lua` and `src/fx/spark_trail.lua` (deleted) | Remove the two entries |
| `AGENTS.md` Layout | Incomplete | Misses `src/npc/`, `src/ipc/handlers/`, `src/emitters/`, `src/player/states/`, `src/utils/level_records.lua` (`ARCHITECTURE.md` lists them) | Add the modules |
| `tests/integration/run.lua:3` | Stale | References `.scratch/integration-testing/` which doesn't exist | Update comment |
| `src/components/pickup.lua:18` | Typo | "annother" | Fix typo |
| `TODO.md` | Current | Low-priority missing-sound-WAVs item matches live comments in `kill_zone.lua`/`pressure_switch.lua` | No action (accurate) |

### 4. Unregistered Test Files (silently dropped coverage)

| File Path | Runners | Notes | Recommendation |
| :--- | :--- | :--- | :--- |
| `tests/unit/mesh_ribbon_emitter_test.lua` | not in `unit/run.lua` | Valid test, never runs | Register |
| `tests/unit/mesh_ribbon_render_test.lua` | not in `unit/run.lua` | Valid test, never runs | Register |
| `tests/unit/state_machine_trytransition_test.lua` | not in `unit/run.lua` | Valid test, never runs | Register |
| `tests/unit/teleport_trail_test.lua` | not in `unit/run.lua` | Valid test, never runs | Register |
| `tests/unit/teleport_travel_state_test.lua` | not in `unit/run.lua` | Valid test, never runs | Register |
| `tests/integration/ladder_catch_test.lua` | not registered | Overlaps `ladder_catch_slide_test.lua` | Reconcile/delete dup |
| `tests/integration/level_layer_render_test.lua` | not registered | Never runs | Register |
| `tests/integration/teleport_clear_test.lua` | not registered | Overlaps `switchable_teleport_test.lua` | Reconcile/delete dup |

---

## Top Priority Action Plan

1. **[High]** Fix stale/inconsistent `mover_platform.lua` speed math (lines 12, 105, 115): update the `100px/s` comments and align `(speed or 100)` fallback with the `or 50` default. References are now in 3 spots and `NOTES.md` itself flags it.
2. **[High]** Delete the broken `collider.lua:80` nil assignment (`self.draw = Collider.collider_draw`) and the dead `World:draw`/`Collider:worldDraw`/`setFixedRotation`/`teleport` physics surface — stale dead code with an actual nil bug.
3. **[High]** Delete orphaned `tests/integration/debug_switch_drawbridge.lua` (raw `print` debug scaffolding, never runs).
4. **[Medium]** Register the 8 unregistered unit/integration test files (or deliberately delete superseded duplicates) — otherwise their coverage is silently dropped.
5. **[Medium]** Resolve the missing-doc drift: `DECISIONS.md` (35 refs), `ADR 0005` (3 refs), and `NOTES.md 2026-08-24` (5 refs) all point to docs that no longer exist.
6. **[Medium]** Extract shared `src/ipc/handler_helpers.lua` for `inGameState()`/`stepFixed(FRAME_DT)` duplicated across 4 handlers.
7. **[Medium]** Collapse per-NPC defaults tables into `NPCConfig.Defaults` (removes copy-paste + the dead `npc_spider.lua` require).
8. **[Medium]** Verify `makelove.toml` shallow globs (`./src/*`, `./res/*`, `./lib/*`) before next package build — nested dirs (`src/map/`, `src/entities/`, `lib/hump/`, `res/img/`) may be dropped.
9. **[Low]** Update stale docs: `AGENTS.md:65` (remove deleted fx files), `AGENTS.md` Layout (add `src/npc/`, `src/ipc/handlers/`, `src/emitters/`, `src/player/states/`), `ARCHITECTURE.md:230` player-state how-to, `run.lua:3` `.scratch/` ref.
10. **[Low]** Name repeated probe/margin magic numbers in `player_sensors.lua`/`ground_support.lua`; unify the 4 duplicated `readFile` fallbacks; consider trimming unused `lib/Slab/` + `lib/hump/` payload.

*Note: prior audit (2026-08-29) issues already resolved since: `particles_test.lua:1` stale comment, diorama `tileSize` fallback, `CONTEXT.md` GameAPI entry, orphaned `src/fx/dust_burst.lua`/`spark_trail.lua` removed.*
