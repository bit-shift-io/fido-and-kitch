# Codebase Audit Summary

**Audit Target:** `fido-and-kitch` (LÖVE 2D puzzle-platformer)  
**Date:** 2026-08-26  

---

## Executive Summary
The codebase is well-organized with clear separation of concerns (entities, components, states, map system, physics). No critical issues found. Overall technical debt is low. Primary risks are a few large files exceeding 400 lines and one completely unused emitter module. Test coverage is strong (529 unit + 132 integration tests passing).

---

## Key Metrics
- **Unused/Orphan Files:** 1
- **Dead Functions/Exports:** 0
- **Commented-Out Code / Debug Logs:** 2 (debug prints in speed_streak.lua)
- **Open TODOs/FIXMEs:** 1 (inline `todo:` in blocker.lua) + 11 tracked in TODO.md

---

## Findings & Recommendations

### 1. Unused Files & Dead Code
| File Path | Type | Details | Recommended Action |
| :--- | :--- | :--- | :--- |
| `src/emitters/ribbon_emitter.lua` | Unused File | Not required anywhere; comment shows incorrect require path (`src.ribbon_emitter` vs actual `src.emitters.ribbon_emitter`) | **Delete** — superseded by `mesh_ribbon_emitter.lua` which is used by `speed_streak.lua` |

### 2. Code Structure & Complexity Smells
| File Path | Issue | Context / Severity | Suggested Refactor |
| :--- | :--- | :--- | :--- |
| `src/player/player_states.lua` | Large file (754 lines) | Contains 8 state classes (Ladder, WalkIdle, Fall, Dead, Wrapped, TeleportTravel, JumpTravel) | Extract each state to its own file under `src/player/states/` — follows existing pattern in `src/npc/states/` |
| `src/ipc/game_api.lua` | Large file (578 lines) | 20+ IPC command handlers in one file | Split into submodules by domain (player, map, entity, debug) |
| `src/npc/npc_base.lua` | Large file (487 lines) | NPC base + 7 state classes instantiated inline | Move NPC states to `src/npc/states/` (already exists) and require them |
| `src/entities/story.lua` | Large file (422 lines) | Single entity with complex dialogue rendering | Extract dialogue rendering to a component or separate module |
| `src/player/player_states.lua` | Long function: `LadderState:update` (120 lines) | Deep nesting, handles aligning/climbing/sliding | Extract `updateAligning`, `updateClimbing`, `updateSliding` are already separate but `update` still routes to them — consider state sub-machine for ladder |
| `src/player/player_states.lua` | Long function: `LadderState:updateClimbing` (70 lines) | Multiple velocity/position calculations | Extract velocity math to `player_movement.lua` |

### 3. Comments & Technical Debt
| File Path | Type | Snippet / Context | Recommendation |
| :--- | :--- | :--- | :--- |
| `src/components/speed_streak.lua:30,35` | Debug Print | `print("SpeedStreak ENABLED - resetting emitter")` / `print("SpeedStreak DISABLED")` | Replace with `Log.debug()` for consistency |
| `src/fx/base.lua:9-13` | Documentation Example | Commented example class definition | Keep — serves as inline documentation for FxBase subclasses |
| `src/emitters/sprite_emitter.lua:5` | Commented Require | `--   local SpriteEmitter = require('src.emitters.sprite_emitter')` | Remove — outdated comment |
| `src/entities/blocker.lua:130` | Inline TODO | `frames = 48, -- todo: make more` | Move to TODO.md or resolve |
| `TODO.md` | Task Tracking | 8 missing sound files listed | Add missing sound assets or remove references |

### 4. Potential Improvements
| Area | Observation | Recommendation |
| :--- | :--- | :--- |
| Component registration | `Tint` component used dynamically via `PickupProp.define` but not explicitly required in main.lua | Add `Tint = require('src.components.tint')` to main.lua globals for discoverability |
| Magic numbers | NPC configs (speeds, radii), jump pad speed (120), path sample count (100) | Consider moving to `movement_constants.lua` or entity-specific constant tables |
| IPC server | `src/ipc/` uses LuaSocket (external C lib) | Document in setup docs; consider pure-Lua alternative for portability |

---

## Top Priority Action Plan
1. **[High]** Delete `src/emitters/ribbon_emitter.lua` — completely unused, causes confusion
2. **[High]** Replace debug `print()` calls in `speed_streak.lua` with `Log.debug()`
3. **[Medium]** Refactor `player_states.lua` — extract each state class to `src/player/states/*.lua` (mirrors `npc/states/`)
4. **[Medium]** Split `ipc/game_api.lua` into domain-specific handlers
5. **[Low]** Move inline TODO in `blocker.lua:130` to TODO.md
6. **[Low]** Add missing sound assets listed in TODO.md (8 files)
7. **[Low]** Consider extracting dialogue rendering from `story.lua` into a component

---

## Positive Observations
- **No FIXME/HACK/XXX tags** in source code (only in third-party libs)
- **Consistent architecture**: entities → components → state machines, clear separation
- **Good test coverage**: 661 tests passing across unit + integration tiers
- **Dynamic entity loading** via `entity_factory` works cleanly with Tiled maps
- **Headless test infrastructure** (`tests/support/headless_bootstrap.lua`) enables real entity construction in unit tests
- **White-box testing seams** (`_internal` tables) on complex entities (drawbridge, pressure_switch, mover_platform, replicator, diorama, map_parallax)
- **IPC control layer** enables programmatic game control for AI agents / automated testing