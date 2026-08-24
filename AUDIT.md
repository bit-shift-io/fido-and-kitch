# Codebase Audit Summary

**Audit Target:** `fido-and-kitch` (LÖVE 2D puzzle-platformer, LuaJIT-style Lua)
**Date:** 2026-08-24
**Baseline:** `main` @ 44f563d ("ladder fix v3")
**Test health at audit:** unit 529/529 passing (`./test-unit.sh`)

---

## Executive Summary

The codebase is in good structural health: conventions are consistent, dynamic-dispatch channels (entity types, FX presets, generator rules) are all wired, error-handling discipline in parsers/settings is above average, and the heavily-commented design modules (camera, diorama, map_parallax, mover_platform) are overwhelmingly accurate. The residual debt clusters into three pockets: **~19 verifiably-dead functions plus 2 never-instantiated FX preset files**, **two large copy-paste families** (map_card/map_list ≈70-line verbatim duplicate; NPC-state locomotion boilerplate ×5), and **documentation drift** — most notably `docs/adr/` was deleted but is still cited by 5 places, and README's primary test instruction (`./test.sh`) points at a script that doesn't exist. No unreachable code and effectively zero open task-tag debt were found.

---

## Key Metrics

- **Unused/Orphan Files:** 2 (`src/fx/dust_burst.lua`, `src/fx/spark_trail.lua` — required into globals, never constructed)
- **Dead Functions/Exports:** 16 methods + ~8 unused `_internal` seam exports
- **Commented-Out Code / Debug Logs:** 1 commented-out function block, 1 wasted query local
- **Open TODOs/FIXMEs/HACKs/XXXs:** 1 (lowercase inline `todo:` in blocker.lua; project correctly routes work to TODO.md)
- **Stale doc references:** 9 findings (2 high)
- **Deep-nesting hotspots (depth ≥ 7):** 3

---

## Findings & Recommendations

### 1. Unused Files & Dead Code

All items below were verified by repo-wide textual search including the dynamic-dispatch channels (Tiled object `type=` attributes across `res/map/*.tmx` + `tests/fixtures/*.lua`, event-bus `bindSelf` dot-references, `_internal` seams). Bare-name matching is conservative — a symbol reported here has zero occurrences anywhere else in the repo.

| File Path | Type | Details | Recommended Action |
| :--- | :--- | :--- | :--- |
| `src/camera.lua:231` | Dead Function | `Camera:getCenter()` — callers use `getDrawParams()` | Delete |
| `src/camera.lua:235` | Dead Function | `Camera:getZoom()` | Delete |
| `src/components/state_machine.lua:30` | Dead Function | `StateMachine:addState()` — states populated only in init | Delete |
| `src/components/timeline.lua:37-45` | Commented-Out Code | Complete `Timeline:setFinishFunc(fn)` wrapped in `--[[ ]]--`; superseded API | Delete (git history keeps it); see also `timeDuration()` at :246 |
| `src/game.lua:122` | Dead Function | `Game:endGame()` — game-over goes through `InGameState.transitionToGameOver` | Delete |
| `src/input/input_config.lua:28,39` | Dead Functions | `setKeyboardMap()`, `resetToDefaults()` — no rebinding UI exists | Delete |
| `src/input/input_manager.lua:34,196,218` | Dead Functions | `forceNonGamepad()` (superseded by `setForcedNonGamepad`), `wasReleased()`, `getAssignedJoystick()` | Delete |
| `src/npc/npc_base.lua:407,485` | Dead Functions | `NPCBase:onCollision()` — bump backend never invokes it; `NPCBase:getSprite()` | Delete |
| `src/entities/exit_door.lua:98,106` | Dead Functions | `exitInstant()`, `exitThroughDoor()` — only reference is CONTEXT.md, which itself calls them dead | Delete + update CONTEXT.md |
| `src/player/player.lua:303` | Dead Function (+ write-only subsystem) | `getPositionHistory()` has no consumer; the position-history *recording* loop (:126-127, :189-199) is therefore write-only. CONTEXT.md:331 claims NPC consumption that doesn't exist | Delete getter; consider removing recording loop together |
| `src/fx/dust_burst.lua` | Orphan File | Required into global `DustBurst` (main.lua:67) but **never constructed anywhere** (contrast: `CoinPickup` used by coin.lua + tests) | Delete file + require/global |
| `src/fx/spark_trail.lua` | Orphan File | Same situation as dust_burst; its own usage example describes a caller that doesn't exist | Delete file + require/global |
| `src/entities/pressure_switch.lua:192` | Unused Seam Export | `_internal.TOLERANCE` — tests alias only `isWeightOn`, `nextActivation` | Drop from seam table (keep local) |
| `src/entities/mover_platform.lua:361-362` | Unused Seam Exports | `_internal.RIDER_TOL`, `_internal.LAND_TOL` — internal use only | Drop from seam table |
| `src/ui/grid_overlay.lua:60` | Unused Seam Export | `_internal.DEFAULT_TILE` | Drop from seam table |
| `src/entities/story.lua:257-260` | Unused Seam Exports | `_internal.CONST.{CORNER_RADIUS, LINE_HEIGHT, MAX_WIDTH, SCREEN_MARGIN}` + `bubble.tailPoints` have zero test refs | Drop from seam table |
| `src/player/player_states.lua:402` | Wasted Work | `local og = PlayerSensors.queryOnGround(...)` computed, never read | Delete line |

Cleared as false alarms (verified dynamically loaded / used): `src/components/tint.lua` (via pickup_prop require-by-name), `src/export_png.lua` (`export=` arg), all `src/utils/*`, `path_follow`/`path` (jump_pad), `variable` (exit_door), `flash_effect` (player/npc/dead_state), all three `tools/level_generator/rules/*` (auto-discovered via `io.popen('ls ...')`).

### 2. Code Structure & Complexity Smells

| File Path | Issue | Context / Severity | Suggested Refactor |
| :--- | :--- | :--- | :--- |
| `src/ui/map_card.lua:41-123` ≡ `src/ui/map_list.lua:71-152` | Verbatim duplication | `collectEntityTypes`, `descriptionFor` (incl. identical 7-entry label table), `titleFor` are byte-for-byte identical (~70 lines, diff-verified) | **High.** Extract shared `src/ui/map_info.lua` |
| `src/npc/states/{chase,follow,flee,wander,patrol}_state.lua` | Boilerplate ×5 | Identical dt-guard; near-identical horizontal accel+clamp+setLinearVelocity block (~95% similar between chase/flee); repeated sqrt-distance idiom ×7 incl. npc_base | **High.** Shared `npc_locomotion.stepHorizontal(entity, dirX, dt)` + one dt-guard |
| `src/map/parallax_renderer.lua:44-45` | Re-hardcoded constants | `minViewTiles = 6`, `tileSize = 32` silently duplicate `camera.lua` `DEFAULT_MIN_VIEW_TILES`/`DEFAULT_TILE_SIZE`; comment even admits it | **Medium-high.** Export/import from camera.lua — drift here is a visual bug |
| `src/entities/ladder.lua:9` vs `src/entities/mover_platform.lua:26` | Duplicated tolerance | Same name/value `LAND_TOL = 6` defined independently — will drift | Move to shared physics-tolerances module |
| `src/ui/map_card.lua:119-138` | Nesting depth 7 | `collisionRects`: for→if→if→for→for→if; same scan loop copied again at :177-193 | Split per-layer-type extractors; dedupe |
| `src/ipc/game_api.lua:534-568, 318-354` | Nesting depth 7 | `getEntities`, `getTileGrid` | Extract `serializeEntity(e)` / `markLadders(grid, objects)` |
| `src/player/player.lua:12-133` | 122-line init | 4 near-identical animation-table blocks differing only in frames/count/duration | Extract `buildAnimations(character)` factory |
| `src/states/ingame_state.lua:20-125` | 106-line load | World/camera creation, spawn, counter-wiring mixed | Split into 3 helpers |
| `src/npc/npc_base.lua:172-320` | 90+75-line update/utilities | Update mixes 5 concerns; dist prologue repeats 4× inside calculateUtilities | Extract per-concern steps |
| `tools/level_generator/main.lua:533` | 12-param function | `assembleObjectiveMap(seed, layout, mapWidth, rows, ladderObjects, objects, waypointObjects, killObjects, waterRows, nextId, nextRungId, background)`; siblings take 11/9/7 | Pass a mutable `draft` table + single IdAlloc |
| `tx, ty, sx, sy` cluster (diorama, parallax_renderer, overlays, Map:draw2) | Systemic 6-param threading | Already caused one documented class of floored-origin bugs (AGENTS.md gotcha) | Introduce a `ViewRect {tx,ty,sx,sy}` once in camera.lua |
| `src/map/entity_factory.lua:69-75` | Removal-while-iterating | `table.remove` by original indices misremoves when >1 entity dies in one pass | Iterate backwards or collect then remove |
| `src/map/entity_factory.lua:84-101` | Closures per instance | `layer:update`/`layer:draw`/`object:exec` closures re-defined per object/layer at load | Hoist to EntityFactory methods taking layer/object args |

**Magic numbers worth centralizing:** fixed-step `1/60` literal in 8+ places (sprite.lua:240, timeline.lua:55, 5 npc states, game_api's independent `FRAME_DT`); NPC accel/speed fallbacks partially shadowing `npc_config.Defaults`; player hitbox 50×50 (player.lua:21-26); cage collider hardcoded `{32,32}` (cage.lua:36); exit-door despawn radius ±64 ×4 (exit_door.lua:142-150); map_list layout numbers + gold color twice.

**Missing error handling (only real gap found):**
| Location | Issue | Severity |
| :--- | :--- | :--- |
| `src/ipc/server.lua:14` | `assert(socket.bind(...))` — port-in-use crashes the whole game at boot | Medium — pcall + Log.warn + disable IPC gracefully |
| `src/ipc/game_api.lua:287-297` | `takeScreenshot` replies "saved" before async result exists; mutates global identity | Low-medium |
| `src/input/input_config.lua:72` | `love.filesystem.write` unguarded — contrast settings.lua:59 which does it right | Low |
| `src/ipc/game_api.lua:276-282` | `loadMap` if/else branches identical — vestigial branch hiding unfinished intent | Low |

(Verified already well-guarded: handler dispatch, JSON decode, XML parse, entity requires, menu map loads, settings, base64.)

### 3. Comments & Technical Debt

| File Path | Type | Snippet / Context | Recommendation |
| :--- | :--- | :--- | :--- |
| `docs/adr/` (missing) | Outdated Document | Directory deleted in bb48581 but still cited by `AGENTS.md:3,87`, `CONTEXT.md:227`, `ARCHITECTURE.md:271-280`, `src/entities/mover_platform.lua:6`. Decisions migrated to root `NOTES.md` (which exists) | **High.** Repoint all 5 citations at NOTES.md or restore ADRs |
| `README.md:21` | Broken instruction | `./test.sh` — script doesn't exist; real entry points are test-unit.sh / test-integration.sh / test-e2e.sh / test-all.sh | **High.** Fix to `./test-unit.sh` (or test-all.sh) |
| `README.md:81` | Wrong controls | Says P2 uses "WASD + left shift"; actual P2 use key is Q (`action_map.lua`) | Fix |
| `src/camera.lua:2` + `CONTEXT.md:5` | Stale claim | Header/glossary say min view is "5×5 tiles"; live constant is `DEFAULT_MIN_VIEW_TILES = 6` (changed post-comment, git-confirmed) | Update both texts |
| `AGENTS.md` Gotchas | Stale gotcha | "CI workflows reference ./install.sh" — workflows now run setup.sh; gotcha itself is obsolete | Remove item |
| `README.md:62` + `src/export_png.lua:158` | Contradiction | Both claim save-dir output; code writes to working directory (`getWorkingDirectory()`, :176; header at :16 agrees) | Fix both comments + README |
| `src/entities/mover_platform.lua:272-273` | Rotted refs | Cites ingame_state.lua:198/199; actual lines now 211/212 | Prefer naming over line numbers |
| `src/diorama.lua:36-39` | Inaccurate default | Comment says outset "tileSize/2" parks frame flush; actual default 14 ≠ 16 (band overlaps playfield 2px) | Align text with value |
| `tests/README.md:44,137` + `tools/README.md:81` | Dead links | Example loads non-existent `res/map/level1.lua`; `.scratch/*/DECISIONS.md` paths don't exist | Use a real map name; mark provenance as historical |
| `TODO.md:16` | Off-by-one | Says 9 missing sounds incl. `character_jump` (referenced nowhere); actual missing count is 8, all others verified referenced | Correct list |
| `src/entities/blocker.lua:130` | Inline tag | `frames = 48, -- todo: make more` | Fold into TODO.md or resolve |

**Clean:** no FIXME/HACK/XXX/WIP tags anywhere; `src/ipc/` has zero stray prints; print interception in main.lua feeds IPC GET_LOG intentionally; TASKS.md fully checked off and consistent; CLAUDE.md/GEMINI.md are pure pointers to AGENTS.md (no divergence); design comments in diorama.lua / map_parallax.lua / camera.lua decay math / mover_platform tolerances spot-checked accurate.

---

## Top Priority Action Plan

1. **[High] Fix broken documentation anchors** — repoint the five stale `docs/adr/` citations (AGENTS.md ×2, CONTEXT.md, ARCHITECTURE.md, mover_platform comment) at `NOTES.md`; replace README's `./test.sh` with the real test scripts; correct README's P2 controls (Q, not left-shift).
2. **[High] Purge verified-dead code** — delete the 16 dead methods, the commented-out `Timeline:setFinishFunc` block, the two never-instantiated FX files (+ their main.lua globals), the unused `og` local, and trim the four unused `_internal` seam exports. All zero-reference, so deletion is behavior-safe; run `./test-all.sh` after.
3. **[Medium] De-duplicate the two big families** — extract shared `map_card`/`map_list` info module (~70 lines saved, one place to keep map metadata in sync) and an NPC locomotion helper for the five state files.
4. **[Medium] Stop constant drift before it bites** — import camera's `DEFAULT_MIN_VIEW_TILES`/`DEFAULT_TILE_SIZE` in parallax_renderer instead of re-hardcoding; unify `LAND_TOL` into a shared physics-tolerance module; introduce one `FIXED_DT` constant.
5. **[Medium] Harden IPC startup** — pcall the `socket.bind` in server.lua so a port conflict logs a warning instead of crashing the game at boot.
6. **[Low] Refactor for readability when next touching those areas** — split the 100+-line Player:init / LadderState:update / InGameState:load; draft-table refactor for the level-generator's 12-param assembler; ViewRect grouping of the `tx,ty,sx,sy` cluster.
