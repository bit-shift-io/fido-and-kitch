# Codebase Audit Summary

**Audit Target:** `fido-and-kitch` (LÖVE 2D puzzle-platformer)  
**Date:** 2026-08-29  

---

## Executive Summary
Well-organized LÖVE 2D codebase with clean component architecture, strong test coverage, and zero open FIXME/TODO tags. Primary technical debt is moderate: duplication across the Tiled parsing pipeline (tmj.lua ↔ tj_tileset.lua), IPC helper boilerplate in 4 handler files, and a handful of un-named magic numbers. **Dead-code re-audit (this session):** 2 orphaned fx modules, 14 fully-dead methods, 13 more methods referenced only by tests, and 7 unused locals. No unreachable statements confirmed. The prior audit's §1 counts (0 orphans / 6 dead methods) are superseded by the table below. Documentation is largely current after the prior audit's fixes, with one stale glossary entry remaining.

---

## Key Metrics
- **Unused/Orphan Files:** 2 — `src/fx/dust_burst.lua`, `src/fx/spark_trail.lua` (no `require` anywhere in repo)
- **Dead Functions/Methods:** 14 with zero callers anywhere (plus 13 referenced only by tests)
- **Commented-Out Code / Debug Logs:** 0 commented-out blocks; ~18 `Log.debug` calls in normal paths (level-gated, acceptable)
- **Open TODOs/FIXMEs:** 0 inline in `src/`; 3 high / 2 medium / 1 low tracked in `TODO.md`
- **Unused Require Statements:** 0 (all 7 removed in prior audit)

---

## Test Baseline

All three tiers GREEN (verified 2026-08-29):
- Unit: **509 passed** (`./test-unit.sh`)
- Integration: **133 passed** (`./test-integration.sh`)
- E2E: **9 files passed** (`./test-e2e.sh`)

---

## Findings & Recommendations

### 1. Unused Files & Dead Code

#### Dead Methods (zero callers anywhere — including tests)

| File:Line | Method | Notes |
| :--- | :--- | :--- |
| `src/components/path.lua:86` | `Path:getPositionAtPercent(pct)` | Backward-compat helper; zero references |
| `src/components/timeline.lua:236` | `Timeline:timeDuration()` | Zero references |
| `src/components/sprite.lua:186` | `Sprite:enter()` | Components aren't reached by FSM `enter` (states only) |
| `src/components/tint.lua:8` | `Tint:enter()` | Same |
| `src/components/flash_effect.lua:64` | `FlashEffect:reset()` | Zero references |
| `src/npc/npc_base.lua:413` | `NPCBase:applyPush()` | Zero references |
| `src/player/player_sensors.lua:20` | `PlayerSensors.queryLadder()` | Zero references (`queryKillZone`/`queryLadderBelow` are live) |
| `src/utils/asset_manager.lua:18` | `AssetManager.getTextureCount()` | Zero references |
| `src/map/init.lua:129` | `Map:draw()` (no-arg overload) | All callers use `map:draw2(...)`; also references never-assigned global `Camera` |
| `src/input/input_manager.lua:186,192` | `InputManager:setDeadzone()`, `setForcedNonGamepad()` | Zero callers |
| `src/ui/debug_overlay.lua:18` | `DebugOverlay:toggle()` | Overlays toggle via `conf.drawphysics/draw_grid/...` flags instead |
| `src/ui/grid_overlay.lua:19` | `GridOverlay:toggle()` | Same |
| `src/ui/sprite_outline_overlay.lua:17` | `SpriteOutlineOverlay:toggle()` | Same |

#### Test-Only Methods (production-dead; pure wrappers over `Timeline` unless noted)

| File:Line | Method | Notes |
| :--- | :--- | :--- |
| `src/components/timeline.lua` | `setDirection`, `getDirection`, `setSpeed`, `getSpeed`, `isPlaying` | Only `tests/unit/timeline_reverse_test.lua` |
| `src/components/sprite.lua:217-231` | `getDirection`, `setSpeed`, `getSpeed`, `isPlaying` | Delegates to the timeline wrappers above; test-only |
| `src/components/sprite.lua:239` | `Sprite:getPositionV()` | `Collider:getPositionV()` (different class) is used everywhere; only `tests/integration/pushable_test.lua:105` |
| `src/utils/settings.lua` | `Settings.reset()` | Only `tests/unit/settings_test.lua` |
| `src/emitters/mesh_ribbon_emitter.lua:261,265` | `Emitter:done()`, `Emitter:reset()` | Only `tests/unit/mesh_ribbon_emitter_test.lua` |

#### Unused Locals (minor)

| File:Line | Issue |
| :--- | :--- |
| `src/entities/exit_door.lua:33` | `local collider` — addComponent result discarded |
| `src/entities/story.lua:25` | `local LINE_HEIGHT = 16` never referenced |
| `src/physics/bump/world.lua:147` | `local actualX` unused (only `actualY`, `cols`, `len`) |
| `src/player/player_movement.lua:190` | `local v_x, v_y` — `v_x` unused |
| `src/player/states/fall_state.lua:21`, `walk_idle_state.lua:29`, `wrapped_state.lua:18` | `local v_x, v_y` — `v_x` unused in each |

No unreachable statements confirmed: a heuristic scan for code-after-return produced only false positives (returns inside `if` branches / table constructors).

**Not dead** (re-verified live this session): `Sprite:setFrameNum` (ladder_state.lua:156), `Sprite:setFacing`, `Sprite:playReverse` (switch.lua:46), `Sprite:reverseFromCurrent` (drawbridge/blocker), `Timeline:play/playReverse`, `Path:getPositionV` (PathFollow/jump_travel_state), `Path{}`, `World:newCollider/queryOverlap/queryBounds`, `Camera:*` (heavy use in InGameState + travel states), `Player:pickup` (dynamic dispatch via `Pickup:contact`), the 8 IPC `GameAPI` handlers (wired through `command_handlers.lua`).

#### Duplicate Line (copy-paste smell)

| File:Line | Issue | Severity |
| :--- | :--- | :--- |
| `src/entities/drawbridge.lua:137–138` | `self.latchedOpen = false` appears twice consecutively | Low — remove one |

#### Orphaned Modules

| File | Evidence |
| :--- | :--- |
| `src/fx/dust_burst.lua` | Zero `require` references anywhere (repo-wide, incl. tests/tools); only AGENTS.md/AUDIT.md doc mentions. No Tiled entity type maps to it |
| `src/fx/spark_trail.lua` | Same |

**Supersedes the prior "No Orphaned Files" claim** — every other `src/` file was re-verified reachable: `export_png.lua` (main.lua:129 + tests), `sprite_props.lua`, `pickup_prop.lua`, `pushable_prop.lua`, `mesh_ribbon_emitter.lua` (via `speed_streak.lua:4`), `web.lua`, `npc_registry.lua`, `npc_locomotion.lua`, `profile.lua`. Entity modules with no static `require` (boulder, cage, exit_door, jump_pad, key, kill_zone, push_box, switch, …) load dynamically by Tiled object `type` via `src/map/entity_factory.lua` `searchPaths` routing — not orphaned.

#### Dead Globals (assigned, never read)

| File:Line | Global | Notes |
| :--- | :--- | :--- |
| `src/main.lua:64-66` | `Particles`, `FxManager`, `CoinPickup` | All code paths go through `local require(...)` instead |
| `src/main.lua:46` | `Slab` | Read only within `main.lua:135` |
| `src/physics/bump/world.lua:1` | `bump` | Read only within that file |

---

### 2. Code Structure & Complexity Smells

#### Long Functions (>50 lines) — Updated

| File:Line | Function | ~Lines | Notes |
| :--- | :--- | :--- | :--- |
| `src/map/tmj.lua:457` | `Tmj.parse` | 156 | **Largest function in codebase**; full map load orchestration |
| `src/ipc/command_handlers.lua:30` | `registerBuiltins` | 162 | 18 IPC commands registered; INPUT/PRESS_KEY/RELEASE_KEY/HOLD_KEY repeat near-identical arg parsing |
| `src/map/tmj.lua:215` | `parseObject` | 124 | 6-param; object property coercion + nested recursion |
| `src/map/tmj.lua:16` | `resolveEmbeddedTileset` | 119 | Grid + collection branches + objectgroup parsing |
| `src/map/tj_tileset.lua:53` | `resolveTsjUncached` | 131 | Near-identical to `resolveEmbeddedTileset` — see duplication below |
| `src/ui/debug_overlay.lua:22` | `draw` | 100 | 7 overlay sections; extract per-section helpers |
| `src/entities/drawbridge.lua:134` | `init` | 97 | Builds deck collider, trigger collider, sprite, sound, switch; extract per-collider setup |
| `src/map/tj_template.lua:22` | `parseTj` | 98 | Template resolution; 98 lines of nested iteration |
| `src/map/parallax_renderer.lua:19` | `drawBackground` | 87 | Per-layer draw logic with scissor math |
| `src/player/states/ladder_state.lua:72` | `update` | 87 | Already delegates to updateAligning/updateClimbing/updateSliding; could extract more |
| `src/npc/npc_base.lua:262` | `calculateUtilities` | 72 | Utility calculation; acceptable for its domain |
| `src/player/player.lua:42` | `init` | 81 | Component wiring; acceptable |

#### Large Files (>400 lines)

| File | Lines | Notes |
| :--- | :--- | :--- |
| `src/map/tmj.lua` | 613 | Grew ~100 lines (added Tmj.parse, expanded parseObject); now largest file |
| `src/npc/npc_base.lua` | 487 | Stable |
| `src/entities/story.lua` | 419 | Many small pure helpers; acceptable internal structure |
| `src/entities/mover_platform.lua` | 363 | Deck offset math, one-way collision, rider carry |
| `src/diorama.lua` | 361 | Void tiling + frame decoration; mostly pure geometry |
| `src/entities/drawbridge.lua` | 324 | Grew with timeline-based open/close |

#### Deep Nesting (≥4 levels)

| File:Line | Depth | Context | Severity |
| :--- | :--- | :--- | :--- |
| `src/export_png.lua:105` | ~7 | `buildColorGrid`: nested loops over layers → tiles → rows → columns → color map | High |
| `src/ui/map_card.lua:63, 120` | ~6 | `collisionRects` / `drawMapThumbnail`: layer → visible → decode → rows → columns | Med |
| `src/map/tmj.lua:523+` | ~4 | `parseObject` property type-cascade: sequential if/elseif (acceptable) | Low |

**Improved:** `src/map/entity_factory.lua` event handler was previously ~depth 7; now ~depth 3 (simplified after refactor).

#### Long Parameter Lists (≥5 params) — High Priority for Refactor

| File:Line | Function | Params | Recommended |
| :--- | :--- | :--- | :--- |
| `src/map/tmj.lua:360` | `parseLayer(layer, mapWidth, mapHeight, tsFirstgidByGid, mapDir, firstgidFor, firstgidForEmbedded, deps)` | **8** | Thread a single `ctx` table; all 8 are parse-context state |
| `src/map/tmj.lua:215` | `parseObject(obj, tsFirstgidByGid, mapDir, firstgidFor, firstgidForEmbedded, deps)` | **6** | Same `ctx` table (4 of these 6 are shared with parseLayer) |
| `src/camera.lua:66` | `computeFraming(targets, mapW, mapH, screenW, screenH, opts)` | 6 | opts aggregates the last param; acceptable |
| `src/player/states/ladder_state.lua:184,237` | `updateClimbing` / `updateSliding` | 6 each | Acceptable for gameplay math |

#### Duplicated Code Patterns — Updated

| Pattern | Files | Severity | Notes |
| :--- | :--- | :--- | :--- |
| Per-tile property/animation/objectgroup parsing | `tmj.lua:37-124` ↔ `tj_tileset.lua:86-173` | **High** | ~60 lines near-identical; object-copy block byte-identical. Extract shared `parseTile()` / `parseTileObject()` |
| IPC `inGameState` guard | `handlers/player.lua:19-30`, `map.lua:3-14`, `entity.lua:4-15`, `debug.lua:3-14` | Med | Identical 12-line block in 4 files; extract to shared util |
| IPC `stepFixed` + `FRAME_DT` | `handlers/player.lua:7-17`, `entity.lua:17-27`, `debug.lua:16-26` | Med | ~10-line frame stepper in 3 files |
| File-reading fallback (`love.filesystem.read` else `io.open`) | `tj_tileset.lua:15-27`, `tj_template.lua:22-38`, `tmj.lua:458-469` | Med | Extract one `readFile(path)` util |
| `clamp(lo,hi,v)` | `camera.lua:50-55`, `parallax_renderer.lua:12-17`, `mesh_ribbon_emitter.lua:29` | Med | 3 homes; hoist to `utils.clamp` |
| Spawn-flash `0.15 * 8` | `player.lua:239`, `player/states/dead_state.lua:15`, `npc/states/dead_state.lua:28` | Med | Raw literal where named constants exist (`npc_base.lua:21-22`); `game_hud.lua:19` even comments "same as the player spawn flash". Promote to shared constant |
| Thumbnail layout math | `map_list.lua:pressed(123-147)` ↔ `map_list.lua:draw(202-265)` | Med | Duplicated `thumbMaxW/thumbScale/thumbW/thumbH/cardGap/pip` geometry in same file; extract `layout()` |
| `THUMBNAIL_WIDTH/HEIGHT` | `map_card.lua:5-6`, `map_list.lua:8-9` | Low | Same values (360/220); share one source |
| `HEART_SIZE = 24` | `lives_hud.lua:5`, `game_hud.lua:13` | Low | Duplicate constant |

#### Magic Numbers — Updated

| File:Line | Value | Context | Severity |
| :--- | :--- | :--- | :--- |
| `src/states/ingame_state.lua:73` | `90.81` | `World:new(0, 90.81, true)` — unexplained gravity | **High** |
| `src/emitters/mesh_ribbon_emitter.lua:160,168-174,214` | `* 255` / `/ 255` | LÖVE uses 0–1 colors natively; this round-trip is redundant and error-prone | **High** |
| `src/diorama.lua:150, 297` | `tileSize or 16` | Fallback is 16 but documented default is 32 (`Diorama.config.tileSize = 32` at line 35) | Med |
| `src/player.lua:51-56` | `width=50, height=50`, `Vector(0,8)`, `physics_arguments={20,30}` | Player dimension/collider magic numbers; should live in constants | Med |
| `src/states/ingame_state.lua:214` | `for i = 1, 4` | Max player count hardcoded | Low |
| `src/player.lua:107-108` | `minSpeed=200, emitRate=100` | SpeedStreak inline tuning | Low |
| `src/player.lua:148` | `x-16 / x+16` | Usable-check probe radius (16px world) | Low |

---

### 3. Comments & Technical Debt

#### No TODO/FIXME/HACK/XXX in `src/`
Zero tags across all production source files.

#### No Commented-Out Code
All `-- code` matches in `src/` are legitimate explanatory comments. The 4 blocks removed in the prior audit remain removed.

#### Stale Test Comment
| File:Line | Issue | Recommendation |
| :--- | :--- | :--- |
| `tests/unit/particles_test.lua:1` | Comment says "tests for src/particles.lua" — file is now `src/emitters/sprite_emitter.lua` | Update comment |

#### Borderline Log.debug Calls (retained, level-gated)
`speed_streak.lua:31,36`, `usable.lua:91`, plus ~15 other `Log.debug` calls across player, ladder, switch, cage, exit_door, entity_factory, fall_state, ladder_state, and ingame_state. All gated behind `Log.level` — acceptable for debug tooling.

---

### 4. Documentation Staleness

#### CONTEXT.md — STALE (GameAPI entry)
| Lines | Issue |
| :--- | :--- |
| 261–265 | `GameAPI` definition lists only `resize, movePlayer, getState, getPlayerPos, restartLevel, goToMenu` and says "No entity spawning or physics modification". Actual GameAPI now also exposes: `spawnEntity`, `stepFrames`, `getEntities`, `getTileGrid`, `loadMap`, `toggleCamera`, `takeScreenshot`, `toggleDebugDraw`, `setJoystickNonGamepad`, `injectInput`, `injectKey`, `holdKey`. The boundary claim is now incorrect. |

**Fix:** Update GameAPI entry to list all current functions and remove the "no entity spawning" boundary claim.

#### ARCHITECTURE.md — CURRENT
Prior audit's fixes are in place: Box2D/love.physics references are now intentional historical context (matching AGENTS.md), module tree includes `src/npc/`, `src/ipc/`, `src/emitters/`, `src/fx/`, `res/bg/`, `res/entities/`, and all current components are listed. No stale references remain.

#### AUDIT.md (this document)
Previous audit's top priorities all resolved. This document supersedes the prior version.

#### NOTES.md / TASKS.md / TODO.md
Current and consistent with the codebase.

---

## Top Priority Action Plan

**Remaining from prior audit (carried forward):**
1. **[High]** Extract shared per-tile parser from `tmj.lua`/`tj_tileset.lua` (~60 duplicated lines; biggest single dedup win)
2. **[Medium]** Unify duplicated IPC helpers (`inGameState`, `stepFixed`/`FRAME_DT`) into `src/ipc/` shared util
3. **[Medium]** Extract shared `clamp()` into `utils.clamp` (3 homes)
4. **[Medium]** Thread a `ctx` table through `tmj` parsers to collapse the 8-param `parseLayer` and 6-param `parseObject`

**New this audit:**
5. **[Medium]** Remove dead code found in the dead-code re-audit: 2 orphaned fx modules (`src/fx/dust_burst.lua`, `src/fx/spark_trail.lua`) and 14 dead methods (table in §1); optionally prune the 13 test-only methods together with their sole tests
6. **[Medium]** Fix duplicate `self.latchedOpen = false` line in `drawbridge.lua:137-138`
7. **[Medium]** Name gravity constant (`90.81` → `GRAVITY` in a constants module or movement file)
8. **[Medium]** Collapse mesh-ribbon `255` round-trip to native LÖVE 0–1 colors
9. **[Medium]** Fix diorama `tileSize or 16` fallback to match documented default `32`
10. **[Medium]** Extract spawn-flash constant (`0.15 * 8` → `SPAWN_FLASH_DURATION`) shared by player, player dead_state, and npc dead_state
11. **[Low]** Update CONTEXT.md GameAPI entry (list all functions, remove stale boundary claim)
12. **[Low]** Update `tests/unit/particles_test.lua:1` comment path
13. **[Low]** Extract shared `readFile()` util (3 identical fallbacks across tj_tileset, tj_template, tmj)
14. **[Low]** Add missing sound assets listed in `TODO.md` (8 WAV files)

---

## Positive Observations

- **Zero FIXME/HACK/XXX tags** in all production source
- **Only 2 orphaned files** (`src/fx/dust_burst.lua`, `src/fx/spark_trail.lua`); every other `src/` file has at least one runtime path
- **Zero commented-out code blocks** in production source
- **Strong test coverage**: 509 unit + 133 integration + 9 e2e; white-box `_internal` seams on complex entities
- **ARCHITECTURE.md is comprehensive and current** after prior audit's fixes
- **Test suite fully green** across all three tiers
- **Clean component architecture**: entities → components → state machines, clear separation of concerns
- **IPC control layer** provides robust programmatic game control for AI agents
- **Template-driven sprite data** (`res/entities/*.tj` + `SpriteProps.fromObject`) keeps entity code free of art literals
