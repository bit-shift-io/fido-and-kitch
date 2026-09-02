# Codebase Audit Summary

**Audit Target:** `fido-and-kitch` (LÖVE 2D puzzle-platformer)  
**Date:** 2026-09-02  

---

## Executive Summary

Healthy LÖVE 2D codebase with clean component architecture and a strong three-tier test suite (85 unit + 85 integration + 12 e2e). The prior audit's high-priority items (dead/broken code, stale mover_platform numbers, NPC defaults duplication, IPC handler boilerplate, unregistered test files) have all been resolved. DECISIONS.md and ADRs 0001–0006 now exist, closing the doc drift flagged previously. Remaining debt is primarily polish: 6 stale `.scratch/` cross-references, 6 dangling `NOTES.md 2026-08-24` pointers, minor code duplication (`formatTime`, `isHeadless`), 3 files over 400 lines, and mixed indentation across 18 files.

## Key Metrics

- **Unused/Orphan Files:** 1 dead module (`src/utils/constants.lua`); 0 orphaned test files (previous orphans resolved)
- **Dead Functions/Methods:** 1 confirmed (`AssetManager.getTextureCount()` — documented but never called)
- **Commented-Out Code:** 1 instance (`src/components/pickup.lua:24`)
- **Open TODOs/FIXMEs:** 0 in first-party code
- **Stale Cross-References:** 16 (6 `.scratch/`, 4 `HANDOFF`, 6 `NOTES.md 2026-08-24`)
- **Long Files (400+):** 3 (`tmj.lua` 611, `npc_base.lua` 525, `story.lua` 418)
- **Long Functions (50+):** 38 (worst: `registerBuiltins` 161 lines, `Tmj.parse` 155)

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
| `src/utils/constants.lua` | Dead module | Defines `GameConstants` table; **never required** by any file in src/ or tests/. All constants duplicated into individual files that use them | Delete |
| `src/utils/asset_manager.lua:18` | Dead export | `getTextureCount()` — zero callers (documented in AGENTS.md but never used) | Delete or keep + accept doc overhead |

### 2. Stale Cross-References

| File Path | Line | Stale Reference | Recommendation |
| :--- | :--- | :--- | :--- |
| `src/entities/drawbridge.lua` | 11 | `.scratch/drawbridge/` | Remove or re-point |
| `tests/e2e/drawbridge_test.lua` | 6–7 | `HANDOFF.md` + `.scratch/drawbridge/` | Remove or re-point |
| `tests/unit/teleport_start_disabled_test.lua` | 4 | `.scratch/procedural-level-generation/DECISIONS.md` | Remove or re-point |
| `tests/support/love_mock.lua` | 4 | `.scratch/integration-testing/` | Remove or re-point |
| `tests/integration/external_tileset_test.lua` | 4 | `.scratch/external-tilesets/` | Remove or re-point |
| `tests/integration/ladder_sound_test.lua` | 2 | `.scratch/sound-component/` + `HANDOFF.md` | Remove or re-point |
| `src/npc/web.lua` | 3 | `HANDOFF gotcha` | Remove or re-point |
| `tests/support/capture.lua` | 35 | `HANDOFF gotcha` | Remove or re-point |
| `src/player/player_movement.lua` | 75 | `NOTES.md 2026-08-24` | Update date or remove |
| `src/entities/ladder.lua` | 206 | `2026-08-24 decision 4` | Update date or remove |
| `tests/integration/ladder_catch_test.lua` | 4 | `NOTES.md 2026-08-24` | Update date or remove |
| `tests/integration/ladder_seam_test.lua` | 6 | `NOTES.md 2026-08-24` | Update date or remove |
| `tests/integration/npc_ladder_test.lua` | 1 | `NOTES.md 2026-08-24` | Update date or remove |
| `tests/integration/ladder_top_test.lua` | 3 | `NOTES.md 2026-08-24` | Update date or remove |

### 3. Code Duplication

| Pattern | Files | Details | Recommendation |
| :--- | :--- | :--- | :--- |
| `formatTime` | `level_complete_state.lua:15`, `map_card.lua:19` | Identical 5-line function copy-pasted | Extract to shared util |
| `isHeadless()` | `sound.lua:17`, `tint.lua:21`, `sprite.lua:11`, `laser_beam.lua:17` | 4 separate local definitions (3 identical checking `love.graphics`, 1 checking `love.audio`) | Extract to shared util |
| `OCCUPANCY_HEIGHT_MARGIN = 32` | `pressure_switch.lua:61`, `drawbridge.lua:305` | Same constant defined in two files | Extract to shared constant |
| IPC handler guard boilerplate | `handlers/{debug,entity,map,player}.lua` | `Helpers.inGameState()` + `if not state` pattern repeated ~6× | Partially addressed (handler_helpers.lua exists), but the guard pattern still duplicated |

### 4. Commented-Out Code

| File Path | Line | Snippet | Recommendation |
| :--- | :--- | :--- | :--- |
| `src/components/pickup.lua` | 24 | `-- utils.instanceOf(entity, Player)` | Remove stale commented-out code |

### 5. Code Structure & Complexity

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

### 6. Magic Numbers

| Pattern | Locations | Recommendation |
| :--- | :--- | :--- |
| Bare `32` (tile size) | 25+ locations across entity files, physics, IPC, diorama | Introduce `TILE_SIZE` constant |
| `1/60` fallback timestep | `timeline.lua:45`, `sprite.lua:248` | Use shared `FRAME_DT` constant |
| NPC tuning values | `npc_rabbit.lua` (`followDistance=40`, `hopHeight=60`), `npc_bird.lua` (`TARGET_FLIGHT_SPEED=150`), `npc_robot.lua` (`maxSpeed=60`), `npc_spider.lua` (`maxSpeed=90`) | Centralize in `npc_config.lua` |

---

## Top Priority Action Plan

1. **[Medium]** Clean 16 stale cross-references (`.scratch/`, `HANDOFF`, `NOTES.md 2026-08-24`) — quick find-and-replace, no logic changes
2. **[Medium]** Delete dead `src/utils/constants.lua` module (never required)
3. **[Medium]** Extract shared `formatTime`, `isHeadless`, `OCCUPANCY_HEIGHT_MARGIN` duplicates
4. **[Low]** Remove commented-out code in `pickup.lua:24`
5. **[Low]** Standardize indentation across 18 mixed files
6. **[Low]** Name magic `32` tile-size literals with a shared constant
7. **[Low]** Break up 3 largest files (`tmj.lua`, `npc_base.lua`, `story.lua`) and 3 longest functions (`registerBuiltins`, `Tmj.parse`, `Drawbridge:init`)

*Note: prior audit (2026-08-30) high/medium items all resolved: dead code cleanup, mover_platform fix, NPC defaults consolidation, IPC handler extraction, test registration, DECISIONS.md authored, ADRs 0001–0006 shipped.*
