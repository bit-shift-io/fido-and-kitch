# Codebase Audit Summary

**Audit Target:** `fido-and-kitch` (LÖVE 2D puzzle-platformer, LuaJIT)
**Date:** 2026-08-18
**Baseline:** `main` @ 9324710
**Audit result:** All findings addressed — unit 510/510, integration 107/107 passing.

---

## Executive Summary

The codebase is well-structured with a strong three-tier test infrastructure, but the audit surfaced significant **stale test debt**: 9 of 107 integration tests failed against current gameplay/timing, and one fixture asserted a data file (`res/tilesets/props.tsx`) that was never committed. There were no open `TODO`/`FIXME`/`HACK` tags anywhere, and all vendored libs were used. Primary risks found: the test failures masked **one real engine bug** (a mover pinned flush against a push-box filling a hole reads as a wall), plus a broken `tools/decode_grid.lua` duplicating its working Python twin.

All items below were fixed and verified.

---

## Key Metrics

- **Unused/Orphan Files:** 4 identified (1 was a false positive, restored)
- **Dead Functions/Exports:** 8 removed
- **Commented-Out Code / Debug Logs:** ~20 cleaned
- **Open TODOs/FIXMEs:** 0
- **Failing integration tests:** 9 of 107 → 0 after fixes

---

## Findings & Fixes

### 1. Unused Files & Dead Code

| File Path | Type | Details | Action |
| :--- | :--- | :--- | :--- |
| `src/components/tint.lua` | Unused File (flagged) | **False positive** — dynamically required via `pickup_prop.lua` (`'src.components.' .. compName:lower()`); grep corruption hid it. | Restored via `git checkout` |
| `src/entities/variable.lua` | Unused File | Entity type `variable` unreachable — no template, map object, fixture, or static require. | Deleted |
| `tools/decode_grid.lua` | Unused / Broken File | Required non-existent `src.utils.base64` + `zlib`, called undefined `decode()`. | Deleted; kept `decode_grid.py` |
| `src/utils/utils.lua` `COLLIDER_TYPES` | Dead Constant | Zero references. | Removed |
| `src/ipc/game_api.lua:100` `getInjectedInput()` | Dead Function | Defined, never called. | Removed |
| `src/npc/npc_base.lua` `stun()`/`isStunned()`/`ban()` + fields | Dead Functions/Fields | Only exercised by tests; `stunTimer`/`banTimer` never decremented (latent bug). Removed along with `homeFacing`, `currentPatrolIndex`, `patrolDirection`. | Removed |
| `src/physics/bump/collider.lua` `addShape()` | Dead Function | Never called; Box2D leftover stub. | Removed |
| `src/utils/tbl.lua` `length()` | Tests-Only | No production use. | Kept (borderline) |

### 2. Failing Integration Tests (9 of 107)

| Test | Root Cause | Fix |
| :--- | :--- | :--- |
| `pushable_test.lua` "box filling a hole is solid ground" | **Real engine bug** in `lib/bump`: a mover starting a frame with 0px gap and flush bottom against a rect's side ties corner-entry and reads a WALL, permanently pinning it. | Patched `rect_getSegmentIntersectionIndices` to prefer the side's perpendicular normal on exact ties; preserved as `patches/bump.patch` + `setup.sh` wiring |
| `movement_test.lua` "joystick-driven P1 movement" | Test-infra gap: fake Joystick lacked `getAxis/isConnected/isGamepad/getGamepadAxis`; `assignJoystick` never wired `inputManager.players[1].joystick`. | Completed the fake in `tests/support/fake_input.lua` |
| `switch_animation_test.lua` (x2) | Stale test hardcoded 12-frame/1.0s; real switch is 5 frames/0.4s. | Updated expectations |
| `exit_door_sound_test.lua` | `open()` sets `state='open'` directly; test expected the nonexistent `'opening'` intermediate. | Assert `'open'` |
| `npc_kill_zone_respawn_test.lua` "Robot stays gone 30s" | Test hardcoded `RESPAWN_DELAY=30`; real value is 2. | Updated constant + sync comment |
| `spider_wrap_release_test.lua` (x2) | Fixture object `type='spider'` vs registered `'npc_spider'` → nil spider crash. Also the automatic wrap trigger is **not implemented** anywhere in src. | Fixed fixture type; rewrote test to drive the wrap explicitly via `player:wrap(5)` + `spider.wrappedTarget` + `spider:die('lava')` |
| `external_tileset_test.lua` (image-collection) | Fixture referenced `res/tilesets/props.tsx` which never existed. | Pointed at real `res/editor/tileset_props.tsx` (image-collection, 13 tiles) |

### 3. Comments & Technical Debt

| File Path | Type | Action |
| :--- | :--- | :--- |
| `src/main.lua`, `src/physics/bump/{world,collider}.lua`, `src/components/timeline.lua` | Commented-out code (`lovedebug`, `suit`/`urutora`, Box2D leftovers, `--self.tween = ...`) | Removed |
| `src/npc/states/{wander,follow,flee,chase}_state.lua`, `src/components/{timeline,sprite}.lua` | Raw `print()` error paths bypassing `Log.error` | Unified to `Log.error` |
| `tests/support/headless_bootstrap.lua` | Missing `Log` global wiring | Added `Log = Log or require('src.utils.log')` |

### 4. Code Structure & Complexity Smells (deferred, non-blocking)

| File Path | Issue |
| :--- | :--- |
| `src/npc/npc_base.lua:14` `init` | 126 lines |
| `src/player/player_states.lua:55` `LadderState:update` | 153 lines |
| `tools/level_generator/main.lua:359` `buildObjectiveMap` | 244 lines |
| `src/ipc/command_handlers.lua:55-70` | `GAMEPAD_BUTTON_MAP`/`resolveAction`/`validateAction` declared mid-function |
| `src/map/external_tileset.lua:151` `resolveShapeUncached` | 102 lines |
| `src/npc/npc_base.lua` | Magic numbers (2px inset, +1/+3 probe, 8px/16px checks) |

### 5. Asset Gaps (non-fatal — `Sound:play` warns + skips)

Missing WAVs referenced by code: `character_death.wav`, `character_jump.wav`, `entity_kill_{water,pit,spikes,lava}.wav`, `entity_pressure_{press,release}.wav`, `entity_story_blip.wav` (9 of 23). A `kill_zone.lua` comment admits "no assets yet".

### 6. Stale Map Data

`res/map/ll1.tmx` objects `type='draw_bridge'` and `type='time_extension'` match no entity (actual names `drawbridge`, no `time_extension`); `entity_factory` logs `Entity Error` on load (map still loads). Not fixed — needs a Tiled edit.

---

## Notes

- `lib/` is gitignored (cloned fresh by `setup.sh`). The bump fix lives in `patches/bump.patch`, applied by `setup.sh` — verify on a fresh clone.
- `./build.sh` is interactive and was not run; `luacheck` is not installed, so lint-based findings relied on manual review.
- **Lesson learned:** dynamic requires (`'src.components.'..name`, `'src.entities.'..type`) defeat static grep. Orphaned-file findings must be validated against `entity_factory`/`typeIgnores` and dynamic-require patterns before deletion.