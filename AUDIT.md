# Codebase Audit Summary

**Audit Target:** `fido-and-kitch` (LÖVE 2D puzzle-platformer)  
**Date:** 2026-08-29  

---

## Executive Summary
The codebase is well-organized with clear separation of concerns. Primary risks are dead code accumulation (unused globals, orphaned functions) and stale documentation (ARCHITECTURE.md contradicts AGENTS.md on physics backend). Test coverage is strong (134 source files, ~200 test files). Three largest files (tmj.lua 512 lines, npc_base.lua 487, story.lua 422) approach but don't exceed the 400-line threshold.

---

## Key Metrics
- **Unused/Orphan Files:** 0
- **Dead Functions/Exports:** 0 (all 12 identified dead exports removed)
- **Commented-Out Code / Debug Logs:** 2 borderline `Log.debug` on hot paths (retained)
- **Open TODOs/FIXMEs:** 0 inline + 5 tracked in TODO.md
- **Unused Require Statements:** 0 (all 7 removed)

---

## Status of This Audit

All cleanup tasks in Phases A–H (see `TASKS.md`) were completed on 2026-08-29.
Removed 12 dead functions/methods, 2 dead global modules, 7 unused requires,
and 4 commented-out code blocks; fixed stale comments and docs. Verified by
`./test-unit.sh` (495 passed) and `./test-integration.sh` (133 passed). The
findings below document what was found and resolved, plus what remains.

## Findings & Recommendations

### 1. Unused Files & Dead Code

#### Dead Global Modules
| File Path | Type | Details | Recommended Action |
| :--- | :--- | :--- | :--- |
| `src/main.lua:67` | Dead Global | `DustBurst = require('src.fx.dust_burst')` — never referenced in src/ or maps | Remove global assignment |
| `src/main.lua:68` | Dead Global | `SparkTrail = require('src.fx.spark_trail')` — never referenced in src/ or maps | Remove global assignment |

#### Dead Functions/Methods
| File Path | Type | Details | Recommended Action |
| :--- | :--- | :--- | :--- |
| `src/npc/npc_registry.lua:38` | Dead Method | `NPCRegistry.despawn(npc)` — never called (live path is `NPCBase:despawnToTarget`) | Remove |
| `src/npc/npc_registry.lua:72` | Dead Method | `NPCRegistry.clearAll()` — never called (only `clear()` is used) | Remove |
| `src/npc/npc_registry.lua:77` | Dead Method | `NPCRegistry.onMapLoad(map)` — never called | Remove |
| `src/npc/npc_registry.lua:102` | Dead Method | `NPCRegistry.onMapUnload()` — never called | Remove |
| `src/npc/npc_config.lua:46` | Dead Method | `NPCConfig.getBehaviorTypes()` — never called | Remove |
| `src/npc/npc_config.lua:54` | Dead Method | `NPCConfig.validate(props)` — never called | Remove |
| `src/utils/profile.lua:60` | Dead Method | `profile.setclock(f)` — never called (only start/stop/reset/report used) | Remove |
| `src/input/input_manager.lua:33-35` | Dead + Broken | `InputManager:isForcedNonGamepad(joystick)` — references undefined global `forcedNonGamepad`, never called | Remove |
| `src/emitters/mesh_ribbon_emitter.lua:73` | Dead Method | `Emitter:setTexture(tex)` — never called (internal setup uses `self._mesh:setTexture`) | Remove |
| `src/utils/utils.lua:5` | Dead Function | `utils.set_funcs` — only reference is commented-out call in bump/world.lua | Remove |
| `src/input/action_map.lua:19-22` | Dead Export | `GAMEPAD_AXES` — exported but never read (pollGamepad uses hard-coded axes) | Remove from return table |

#### Unused Require Statements
| File Path | Line | Unused Require | Details |
| :--- | :--- | :--- | :--- |
| `src/entities/jump_pad.lua` | 1 | `local Log = require('src.utils.log')` | No `Log.` call in file |
| `src/entities/npc_rabbit.lua` | 5 | `local Vector = require('lib.hump.vector')` | No Vector usage |
| `src/fx/teleport_burst.lua` | 5 | `local Particles = require('src.emitters.sprite_emitter')` | Class inherits FxBase; Particles unused |
| `src/player/player.lua` | 3 | `local GroundSupport = require('src.player.ground_support')` | Used in player_sensors.lua, not here |
| `src/player/states/walk_idle_state.lua` | 2 | `local Log = require('src.utils.log')` | No `Log.` call |
| `src/ui/map_card.lua` | 1 | `local Log = require('src.utils.log')` | No `Log.` call |
| `src/ipc/handlers/player.lua` | 2 | `local json = require('lib.dkjson')` | No `json.` call in file |

#### Commented-Out Code
| File Path | Line | Snippet | Recommendation |
| :--- | :--- | :--- | :--- |
| `src/physics/bump/collider.lua` | 19 | `--Class.include(self, col)` | Remove (annotated "this does not work!") |
| `src/physics/bump/world.lua` | 12 | `--utils.set_funcs(w, w._world)` | Remove (utils.set_funcs is dead) |
| `src/game.lua` | 69, 74 | `--suit.textinput(t)` / `--suit.keypressed(key)` | Remove (suit library not in use) |

### 2. Code Structure & Complexity Smells

#### Long Functions (>50 lines)
| File Path | Function | Lines | Details |
| :--- | :--- | :--- | :--- |
| `src/map/tmj.lua:16` | `resolveEmbeddedTileset` | 109 | Does three distinct jobs (grid, image-collection, tileoffset) |
| `src/map/tmj.lua:282` | `parseLayer` | 94 | Complex layer parsing logic |
| `src/entities/cage.lua:6` | `Cage:init` | 76 | Entity initialization |
| `src/npc/npc_base.lua:262` | `NPCBase:calculateUtilities` | 72 | Utility calculation |
| `src/entities/teleport.lua:69` | `Teleport:use` | 62 | Use interaction |
| `src/entities/exit_door.lua:13` | `ExitDoor:init` | 57 | Entity initialization |
| `src/emitters/mesh_ribbon_emitter.lua:79` | `Emitter:update` | 53 | Particle update |

#### Large Files (near 400 lines)
| File Path | Lines | Status |
| :--- | :--- | :--- |
| `src/map/tmj.lua` | 512 | Largest file; high complexity |
| `src/npc/npc_base.lua` | 487 | NPC base class |
| `src/entities/story.lua` | 422 | Dialogue rendering |

#### Deep Nesting (3+ levels)
| File Path | Lines | Depth | Details |
| :--- | :--- | :--- | :--- |
| `src/export_png.lua` | 100-110 | ~8 | 4 nested loops/ifs for tile rendering |
| `src/ui/map_card.lua` | 59-74 | ~9 | Nested loops with table literals |
| `src/map/tmj.lua` / `tj_tileset.lua` | various | 4-6 | Repeated property/animation/objectgroup parsing |
| `src/map/entity_factory.lua` | 89-105 | ~7 | Event execution handler |

#### Magic Numbers
| File Path | Line | Value | Context |
| :--- | :--- | :--- | :--- |
| `src/states/ingame_state.lua` | 73 | `90.81` | Unexplained gravity constant |
| `src/emitters/mesh_ribbon_emitter.lua` | 165-179 | `255` | Repeated ~10× for alpha conversion |
| `src/ui/map_card.lua` | 77-78 | `16` | Minimum tile size, repeated |
| `src/diorama.lua` | 150, 297 | `16` | Inconsistent fallback (config default is 32) |

#### Duplicated Constants
| Constant | Files | Values |
| :--- | :--- | :--- |
| `HEART_SIZE` | game_hud.lua:13, lives_hud.lua:5 | 24 (identical) |
| `THUMBNAIL_WIDTH/HEIGHT` | map_card.lua:6-7, map_list.lua:8-9 | 360/220 (identical) |
| `DEFAULT_TILE_SIZE` | camera.lua:25, grid_overlay.lua:12 | 32 (identical) |
| `FRAME_DT` | ipc/handlers/player.lua:8, entity.lua:17, debug.lua:16 | 1/60 (identical) |

#### Duplicated Code Patterns
| Pattern | Files | Details |
| :--- | :--- | :--- |
| Per-tile parsing | tmj.lua:37-124, tj_tileset.lua:86-169 | Near-identical property/animation/objectgroup blocks |
| `clamp` helper | camera.lua:50-53, parallax_renderer.lua:12-15 | Identical function |
| IPC `stepFixed`/`inGameState` | ipc/handlers/*.lua (4 files) | ~9-line frame stepper + guard duplicated |
| File-reading fallback | tj_template.lua:26-34, tmj.lua:381-388, tj_tileset.lua:24 | Same pattern |

#### Long Parameter Lists (5+)
| File Path | Function | Params |
| :--- | :--- | :--- |
| `src/camera.lua:66` | `Camera.computeFraming` | 6 |
| `src/map/map_parallax.lua:29` | `computeCameraCenter` | 6 |
| `src/player/states/ladder_state.lua:184` | `updateClimbing` | 6 |
| `src/player/states/ladder_state.lua:237` | `updateSliding` | 6 |

### 3. Comments & Technical Debt

#### Stale Comments
| File Path | Line | Issue | Recommendation |
| :--- | :--- | :--- | :--- |
| `src/emitters/sprite_emitter.lua` | 1 | Mislabels file as "particles.lua" | Fix to "sprite_emitter.lua" |
| `src/components/usable_sparkle.lua` | 10 | References non-existent `src/particles.lua` | Update to `src/emitters/sprite_emitter.lua` |
| `src/entities/exit_door.lua` | 197 | Empty stub `ExitDoor:checkEndGame()` | Remove dead code |
| `src/entities/exit_door.lua` | 2 | Describes legacy `actor_count` mechanism | Update to reflect `all_cages_unlocked` event |

#### Borderline Debug Logs
| File Path | Line | Details | Recommendation |
| :--- | :--- | :--- | :--- |
| `src/components/speed_streak.lua` | 31, 36 | `Log.debug("SpeedStreak ENABLED/DISABLED")` | Consider removing (hot path) |
| `src/components/usable.lua` | 91 | `Log.debug('usable is being used')` | Consider removing (hot path) |

### 4. Documentation Staleness

#### ARCHITECTURE.md — STALE (physics backend)
| Line | Issue |
| :--- | :--- |
| 13 | "love.physics (Box2D) available via `conf.t.physics`" — no such config |
| 48-49 | "world.lua — Thin wrapper selecting physics backend" — backend removed |
| 53 | "physics/ — Swappable backends (bump, love/Box2D)" — only bump/ exists |
| 67, 114, 118, 200, 268 | Multiple references to love/Box2D backend and `conf.t.physics` |

**Fix:** Remove all love/Box2D references; update module tree (§2) to include `res/bg/`, `res/editor/`, `src/npc/`, `src/ipc/`, `src/player/states/`, `src/emitters/`, `src/fx/`; add missing components (Sound, Tint, UsableSparkle, Pushable, SpeedStreak, Flash).

#### AUDIT.md — SUBSTANTIALLY STALE
Previous audit's top priorities are all resolved:
- `src/emitters/ribbon_emitter.lua` — deleted
- `speed_streak.lua` debug prints — replaced with `Log.debug`
- `player_states.lua` (754 lines) — split to `src/player/states/` (now 17 lines)
- `ipc/game_api.lua` (578 lines) — split to `src/ipc/handlers/*.lua`

#### CONTEXT.md — PARTIALLY STALE
Six glossary entries describe removed systems:
- Background prop (bush/cloud), Gradient object, Cloud spawner, Wind, Depth, Proximity component

#### NOTES.md — COMPLETED
All planned TMX→TMJ migration tasks are done; should be marked complete or archived.

#### `src/particles.lua` Path — INCORRECT
Referenced in AGENTS.md and `usable_sparkle.lua:10` but doesn't exist; actual file is `src/emitters/sprite_emitter.lua`.

---

## Top Priority Action Plan

**Resolved (2026-08-29):**
1. ~~[High] Remove dead globals (`DustBurst`, `SparkTrail`) and 12 dead functions/methods~~ — done
2. ~~[High] Remove 7 unused require statements and 4 commented-out code blocks~~ — done
3. ~~[High] Update ARCHITECTURE.md physics-backend sections (9 stale lines) and module tree~~ — done
4. ~~[Medium] Mark NOTES.md as completed; update CONTEXT.md (remove 6 stale entries)~~ — done
5. ~~[Low] Fix `src/particles.lua` path references in AGENTS.md and usable_sparkle.lua~~ — done

**Remaining (lower priority, optional refactors):**
6. **[Medium]** Extract shared per-tile parser from tmj.lua/tj_tileset.lua (~60 duplicated lines)
7. **[Medium]** Unify duplicated utilities (clamp, IPC stepFixed/inGameState, shared constants)
8. **[Low]** Name magic values (gravity 90.81, repeated 255 byte conversion)
9. **[Low]** Remove 2 borderline `Log.debug` calls on hot paths (speed_streak.lua:31,36, usable.lua:91)
10. **[Low]** Add missing sound assets listed in TODO.md (8 files)

---

## Positive Observations
- **Zero FIXME/HACK/XXX tags** in source code
- **Consistent architecture**: entities → components → state machines, clear separation
- **Strong test coverage**: ~200 test files across unit/integration/e2e tiers
- **White-box testing seams** (`_internal` tables) on complex entities
- **IPC control layer** enables programmatic game control for AI agents
- **Headless test infrastructure** enables real entity construction in unit tests
- **Dead code is easily identifiable** — no hidden dependencies or circular imports
