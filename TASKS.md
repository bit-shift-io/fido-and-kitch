# PLAN - Audit remediation (AUDIT.md, fx assets excluded)

Fix every finding in `AUDIT.md` except the two orphan FX preset files
(`src/fx/dust_burst.lua`, `src/fx/spark_trail.lua` stay). Order matters:
doc fixes first, dead-code purges before refactors that touch the same files.
Validate after each phase with `./test-unit.sh` (integration/e2e where noted).

## Phase A — Docs & comments [High]

- [x] 1. AGENTS.md: repoint both `docs/adr/` cites (lines 3, 87) at root `NOTES.md`; delete obsolete "CI workflows reference ./install.sh" gotcha; fix dead `res/map/level1.lua` harness example (line 111) to a real map (`res/map/sandbox.tmx`).
- [x] 2. CONTEXT.md: repoint `docs/adr/` cite (:227) at NOTES.md; correct :331 false claim that NPCs consume player position history (they don't); fix :5 glossary "5×5 tiles" → 6×6 (`DEFAULT_MIN_VIEW_TILES = 6`).
- [x] 3. ARCHITECTURE.md: repoint `docs/adr/` cites (:271 table row, :280 pointer) at NOTES.md.
- [x] 4. README.md: replace nonexistent `./test.sh` (:21) with the real scripts (`./test-unit.sh` / `./test-integration.sh` / `./test-e2e.sh` / `./test-all.sh`); fix P2 controls (:81) to "WASD + Q"; fix export-png output-location wording (:62) to working directory.
- [x] 5. Sweep remaining stale `docs/adr/` comments in code (comment-only, mechanical): `src/world.lua:3`, `src/map/tmx.lua:3`, `src/entities/drawbridge.lua:19` → point at NOTES.md.
- [x] 6. `src/export_png.lua`: fix header comment (:16) claiming save-dir output — code writes to working directory (:176).
- [x] 7. `tests/README.md` (:44, :137): use a real map in examples (`res/map/sandbox.tmx`); `tools/README.md` (:81): mark `.scratch/*/DECISIONS.md` references as historical provenance.
- [x] 8. `src/camera.lua`: fix header comment (:2) "5×5 tiles" → 6×6; delete dead `Camera:getCenter()` (:231) and `Camera:getZoom()` (:235).
- [x] 9. `src/entities/mover_platform.lua`: repoint header adr cite (:6) at NOTES.md; replace rotted line-number refs (:272-273 citing old ingame_state lines) with symbol names; drop unused `_internal.RIDER_TOL`/`_internal.LAND_TOL` exports (keep locals).
- [x] 10. `src/diorama.lua` (:36-39): align outset comment with actual default 14 (not "tileSize/2 flush"); note the 2px band overlap honestly.
- [ ] 11. TODO.md: correct missing-sounds list — 8 items, not 9; drop `character_jump` (referenced nowhere).
- [x] 12. `src/entities/blocker.lua` (:130): resolve inline `-- todo: make more` by folding intent into TODO.md.

## Phase B — Dead-code purge [High] (all zero-reference, behavior-safe)

- [x] 13. `src/components/state_machine.lua`: delete `StateMachine:addState()` (:30).
- [ ] 14. `src/game.lua`: delete `Game:endGame()` (:122) — superseded by InGameState.transitionToGameOver.
- [x] 15. `src/input/input_manager.lua`: delete `forceNonGamepad()` (:34), `wasReleased()` (:196), `getAssignedJoystick()` (:218).
- [x] 16. `src/input/input_config.lua`: delete `setKeyboardMap()` (:28) + `resetToDefaults()` (:39); guard the unguarded `love.filesystem.write` (:72) pcall-style like settings.lua does.
- [x] 17. `src/npc/npc_base.lua`: delete `NPCBase:onCollision()` (:407, bump never invokes it) and `NPCBase:getSprite()` (:485).
- [x] 18. `src/entities/exit_door.lua`: delete `exitInstant()` (:98) + `exitThroughDoor()` (:106); while there, name the hardcoded ±64 despawn-radius literals (:142-150) as one constant.
- [x] 19. `src/player/player.lua`: delete `getPositionHistory()` (:303) AND the now write-only recording loop (:126-127, :189-199) — no consumer exists.
- [x] 20. `src/player/player_states.lua` (:402): delete wasted `local og = queryOnGround(...)` — computed, never read.
- [x] 21. `src/components/timeline.lua` (:37-45): delete commented-out `Timeline:setFinishFunc` block (git history keeps it).
- [x] 22. Trim unused `_internal` seam exports: `_internal.TOLERANCE` in `src/entities/pressure_switch.lua` (:192) and `_internal.DEFAULT_TILE` in `src/ui/grid_overlay.lua` (:60) — keep locals.
- [x] 23. `src/entities/story.lua` (:257-260): drop zero-test-ref seam exports `_internal.CONST.{CORNER_RADIUS, LINE_HEIGHT, MAX_WIDTH, SCREEN_MARGIN}` + `bubble.tailPoints`.

## Phase C — De-duplication [Medium-High]

- [x] 24. Extract shared `src/ui/map_info.lua` from the verbatim ~70-line duplicate: `collectEntityTypes`, `descriptionFor` (+ its 7-entry label table), `titleFor`; rewire `src/ui/map_card.lua` + `src/ui/map_list.lua` to use it. While in map_list, name the duplicated layout numbers + gold color as named constants.
- [ ] 25. `src/ui/map_card.lua`: split nesting-depth-7 `collisionRects` (:119-138) into per-layer-type extractors and dedupe the repeated scan loop (:177-193).
- [x] 26. Create `src/npc/npc_locomotion.lua` with `stepHorizontal(entity, dirX, dt)` (shared accel/clamp/setLinearVelocity block sourced from `npc_config.Defaults`, no per-call fallback literals) + dt-guard; convert `chase_state.lua` as the pilot.
- [x] 27. Convert `src/npc/states/follow_state.lua` + `flee_state.lua` onto `npc_locomotion.stepHorizontal`.
- [x] 28. Convert `src/npc/states/wander_state.lua` + `patrol_state.lua` onto the helper (dt-guard + horizontal block only; keep their unique logic local).
- [x] 29. `src/npc/npc_base.lua`: split the 90+75-line update/utilities blocks (:172-320) into per-concern steps and dedupe the 4× repeated distance prologue (reuse sqrt-distance idiom via locomotion helper).

## Phase D — Constant-drift control [Medium]

- [x] 30. `src/map/parallax_renderer.lua` (:44-45): import `DEFAULT_MIN_VIEW_TILES`/`DEFAULT_TILE_SIZE` from `src/camera.lua` instead of re-hardcoding `minViewTiles = 6`/`tileSize = 32`.
- [x] 31. Create shared physics-tolerance home for `LAND_TOL = 6` (e.g. `src/utils/tolerances.lua`); consume from `src/entities/ladder.lua` (:9) and `src/entities/mover_platform.lua` (:26) so the twins can't drift.

## Phase E — IPC hardening [Medium]

- [x] 32. `src/ipc/server.lua` (:14): pcall `socket.bind` — on port-in-use Log.warn and disable IPC gracefully instead of crashing the boot.
- [x] 33. `src/ipc/game_api.lua` cleanup bundle (one file): reply to `takeScreenshot` after async result + stop mutating global identity (:287-297); collapse identical if/else branches in `loadMap` (:276-282); extract `serializeEntity(e)` + `markLadders(grid, objects)` to flatten depth-7 `getEntities`/`getTileGrid` (:534-568, :318-354); route its independent `FRAME_DT` through the shared fixed-step constant.

## Phase F — Readability refactors [Low]

- [x] 34. `src/player/player.lua`: extract `buildAnimations(character)` factory collapsing the 4 near-identical animation-table blocks in the 122-line init (:12-133).
- [x] 35. `src/states/ingame_state.lua`: split the 106-line `load` (:20-125) into 3 helpers (world/camera creation, spawn placement, counter wiring).
- [x] 36. `src/map/entity_factory.lua`: fix removal-while-iterating (:69-75, iterate backwards or collect-then-remove) and hoist per-instance `layer:update`/`layer:draw`/`object:exec` closures (:84-101) to EntityFactory methods taking layer/object args.
- [x] 37. (stale — draft table removed) `tools/level_generator/main.lua` (:533): refactor 12-param `assembleObjectiveMap` to take a mutable `draft` table + single IdAlloc, matching sibling signatures.
- [x] 38. Introduce `ViewRect {tx,ty,sx,sy}` in `src/camera.lua` and thread it through `Map:draw2` (preserving the floored-origin contract).
- [x] 39. Adopt ViewRect in `src/map/parallax_renderer.lua` + `src/diorama.lua` draw paths (replacing the 4-param threading; keep floored-origin parity).
- [x] 40. Adopt ViewRect across overlays (debug/grid/sprite-outline) — last, smallest blast radius.
- [x] 41. Full validation: `./test-all.sh`; spot-check visuals via `./run.sh debug drawphysics map=sandbox` (parallax/frame alignment after ViewRect adoption).

## Excluded (per user)

- `src/fx/dust_burst.lua` / `src/fx/spark_trail.lua` deletion + main.lua require/global removal — intentionally NOT planned.
