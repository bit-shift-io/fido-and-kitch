# Codebase Audit Summary

**Audit Target:** `fido-and-kitch` (LÖVE 2D puzzle-platformer)  
**Date:** 2026-09-02  

---

## Executive Summary

Healthy LÖVE 2D codebase with clean component architecture and a strong three-tier test suite (85 unit + 85 integration + 12 e2e). The prior audit's high-priority items (dead/broken code, stale mover_platform numbers, NPC defaults duplication, IPC handler boilerplate, unregistered test files) have all been resolved. DECISIONS.md and ADRs 0001–0006 now exist, closing the doc drift flagged previously. The 2026-09-02 audit's medium-priority items (stale cross-references, dead code, duplication) have also been resolved. Remaining debt is primarily polish: magic tile-size literals, mixed indentation, and long functions.

## Key Metrics

- **Unused/Orphan Files:** 0 dead modules (constants.lua deleted)
- **Dead Functions/Methods:** 1 confirmed (`AssetManager.getTextureCount()` — documented but never called)
- **Commented-Out Code:** 0 instances (pickup.lua:24 fixed)
- **Open TODOs/FIXMEs:** 0 in first-party code
- **Stale Cross-References:** 0 (all 16 cleaned)
- **Long Files (400+):** 3 (`tmj.lua` 611, `npc_base.lua` 525, `story.lua` 418)
- **Long Functions (50+):** 38 (worst: `registerBuiltins` 161 lines, `Tmj.parse` 155)

---

## Resolved Since Last Audit (2026-09-02)

- All 16 stale cross-references cleaned (`.scratch/`, `HANDOFF`, `NOTES.md 2026-08-24`); one straggler in `tests/README.md:137` fixed
- `src/utils/constants.lua` was already deleted before this audit; verified zero require references
- `src/components/pickup.lua:24` commented-out `utils.instanceOf` removed
- `formatTime` already extracted to `src/utils/format.lua` (`Format.time`); dead `MapCard.formatTime` export removed
- `MEDAL_COLORS` deduplicated into `Format.MEDAL_COLORS`; local copies in `level_complete_state.lua` and `map_card.lua` replaced with aliases
- `isHeadless()` extracted to `src/utils/headless.lua` (`Headless.isGraphics()`, `Headless.isAudio()`); updated 4 callers; removed dead local in `sprite.lua`
- `OCCUPANCY_HEIGHT_MARGIN` was already extracted to `src/utils/geom.lua`

---

## Resolved Since Last Audit (2026-08-30)

All Phase 1–5 tasks from the previous audit are complete:
- Dead/broken physics code removed (`collider_draw` nil, `World:draw`, `worldDraw`)
- Dead `decideLadderMovement`, `exit_door.reset/add`, `input_config.save/serialize`, `tmj.embeddedKeySig` removed
- `npc_config.lua` dead fields trimmed, per-NPC defaults collapsed into `NPCConfig.Defaults`
- IPC handler duplication extracted to `src/ipc/handler_helpers.lua`
- 8 unregistered test files now registered
- `mover_platform.lua` speed defaults corrected (100→50)
- DECISIONS.md authored (147 lines, Q1–Q11); ADRs 0001–0006 all exist
- `pickup.lua:18` typo "annother" fixed

---

## Findings & Recommendations

### 1. Unused Files & Dead Code

| File Path | Type | Details | Recommended Action |
| :--- | :--- | :--- | :--- |
| `src/utils/asset_manager.lua:18` | Dead export | `getTextureCount()` — zero callers (documented in AGENTS.md but never used) | Delete or keep + accept doc overhead |

### 2. Code Duplication (Remaining)

| Pattern | Files | Details | Recommendation |
| :--- | :--- | :--- | :--- |
| IPC handler guard boilerplate | `handlers/{debug,entity,map,player}.lua` | `Helpers.inGameState()` + `if not state` pattern repeated ~6× | Partially addressed (handler_helpers.lua exists), but the guard pattern still duplicated |

### 3. Code Structure & Complexity

| File Path | Issue | Context / Severity | Suggested Refactor |
| :--- | :--- | :--- | :--- |
| `src/map/tmj.lua` (611 lines) | File length | Largest file; mixed parsing + tileset + template concerns | Split parse helpers into sub-modules |
| `src/npc/npc_base.lua` (525 lines) | File length | Core NPC logic + states + utility AI | Extract utility-weight AI |
| `src/entities/story.lua` (418 lines) | File length | Entity + dialog/bubble rendering | Split render helpers |
| `src/ipc/command_handlers.lua:30` | Function 161 lines | `registerBuiltins` — ~20 closures with repeated validation | Extract validator helper |
| `src/map/tmj.lua:455` | Function 155 lines | `Tmj.parse` | Split into sub-parsers |
| `src/entities/drawbridge.lua:142` | Function 142 lines | `Drawbridge:init` | Split into sub-init helpers |
| `src/entities/laser_beam_resolver.lua:101` | 11 params | `castSegment(x1,y1,direction,farEndpointFn,querySegmentFn,bounceCount,segments,killed,destroyed,activated,pivotEntity)` | Use parameter table |
| `src/ui/grid_overlay.lua:22` | 9 params | `computeGridLines(mapW,mapH,tx,ty,sx,sy,screenW,screenH,tile)` | Use parameter table |
| 18 files | Mixed indentation | Tabs + spaces mixed at line-start level in `components/`, `diorama.lua`, `game.lua`, `main.lua`, etc. | Pick one style, fix the 18 files |

### 4. Magic Numbers

| Pattern | Locations | Recommendation |
| :--- | :--- | :--- |
| Bare `32` (tile size) | 25+ locations across entity files, physics, IPC, diorama | Introduce `TILE_SIZE` constant |
| `1/60` fallback timestep | `timeline.lua:45`, `sprite.lua:248` | Use shared `FRAME_DT` constant |
| NPC tuning values | `npc_rabbit.lua` (`followDistance=40`, `hopHeight=60`), `npc_bird.lua` (`TARGET_FLIGHT_SPEED=150`), `npc_robot.lua` (`maxSpeed=60`), `npc_spider.lua` (`maxSpeed=90`) | Centralize in `npc_config.lua` |

---

## Top Priority Action Plan

1. **[Low]** Standardize indentation across 18 mixed files
2. **[Low]** Name magic `32` tile-size literals with a shared constant
3. **[Low]** Break up 3 largest files (`tmj.lua`, `npc_base.lua`, `story.lua`) and 3 longest functions (`registerBuiltins`, `Tmj.parse`, `Drawbridge:init`)

*Note: prior audit (2026-08-30) high/medium items all resolved; 2026-09-02 audit medium items all resolved.*
