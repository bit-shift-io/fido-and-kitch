# Cleanup audit findings (grill 2026-08-29)

Plan from `AUDIT.md` (2026-08-29 audit). Target end-state: remove dead code,
fix stale/inaccurate docs, and reconcile the three stale docs (ARCHITECTURE.md,
CONTEXT.md, NOTES.md) with reality. Ordered bottom-up (delete leaves before
dependents; docs last). Each task affects at most 1-2 files.

## Phase A — Remove dead globals + dead functions

- [x] `src/main.lua` — remove dead globals `DustBurst = require('src.fx.dust_burst')` (line 67) and `SparkTrail = require('src.fx.spark_trail')` (line 68). Keep the modules themselves (used via `map.fx:add/burst` in real code paths if any).
- [x] `src/input/input_manager.lua` — remove dead + broken method `InputManager:isForcedNonGamepad(joystick)` (lines 33-35); it references undefined global `forcedNonGamepad` and is never called.
- [x] `src/input/action_map.lua` — remove dead export `GAMEPAD_AXES` (lines 19-22) from the return table (`pollGamepad` in input_manager.lua uses hard-coded axes instead).
- [x] `src/utils/profile.lua` — remove dead `profile.setclock(f)` (line 60), keep live `start/stop/reset/report/query`.
- [x] `src/utils/utils.lua` — remove dead `utils.set_funcs` (line 5) after removing its only caller, the commented-out call in `src/physics/bump/world.lua:12` (Phase B).
- [x] `src/emitters/mesh_ribbon_emitter.lua` — remove dead public method `Emitter:setTexture(tex)` (line 73); internal texture setup uses `self._mesh:setTexture` directly.

## Phase B — Remove dead NPC registry/config methods

- [x] `src/npc/npc_registry.lua` — remove 4 dead methods: `despawn(npc)` (line 38, live path is `NPCBase:despawnToTarget`), `clearAll()` (line 72, only `clear()` is wired), `onMapLoad(map)` (line 77), `onMapUnload()` (line 102).
- [x] `src/npc/npc_config.lua` — remove 2 dead methods: `getBehaviorTypes()` (line 46) and `validate(props)` (line 54).

## Phase C — Remove unused requires + commented-out code

- [x] Remove 7 unused require statements: `src/entities/jump_pad.lua:1` (`Log`), `src/entities/npc_rabbit.lua:5` (`Vector`), `src/fx/teleport_burst.lua:5` (`Particles`), `src/player/player.lua:3` (`GroundSupport`), `src/player/states/walk_idle_state.lua:2` (`Log`), `src/ui/map_card.lua:1` (`Log`), `src/ipc/handlers/player.lua:2` (`json`).
- [x] `src/physics/bump/collider.lua` — remove commented-out `--Class.include(self, col)` (line 19, annotated "this does not work!").
- [x] `src/physics/bump/world.lua` — remove commented-out `--utils.set_funcs(w, w._world)` (line 12) once Phase A removes `set_funcs`.
- [x] `src/game.lua` — remove stale commented-out `--suit.textinput(t)` (line 69) and `--suit.keypressed(key)` (line 74); suit GUI library is not in use.

## Phase D — Remove dead stubs + fix stale code comments

- [x] `src/entities/exit_door.lua` — remove empty dead stub `ExitDoor:checkEndGame()` (line 197); fix stale header comment (line 2) describing legacy `actor_count` mechanism → real mechanism is the `all_cages_unlocked` event.
- [x] `src/emitters/sprite_emitter.lua` — fix stale header comment (line 1) mislabeling file as "particles.lua" → "sprite_emitter.lua".
- [x] `src/components/usable_sparkle.lua` — fix stale comment (line 10) referencing non-existent `src/particles.lua` → `src/emitters/sprite_emitter.lua`.

## Phase E — Fix AGENTS.md path/consistency

- [x] `AGENTS.md` — fix `src/particles.lua` reference (the low-level emitter engine) → `src/emitters/sprite_emitter.lua`; expand `src/fx/` list to include `manager.lua`, `jump_pad_streak.lua`, `teleport_burst.lua`, `teleport_trail.lua`.

## Phase F — Fix ARCHITECTURE.md (stale physics backend + module tree)

- [x] `ARCHITECTURE.md` — remove all love/Box2D backend references: `conf.t.physics` (lines 13, 67, 114), "world.lua — Thin wrapper selecting physics backend" (line 48), "Swappable backends (bump, love/Box2D)" (line 53), "Love/Box2D Backend (`src/physics/love/`)" (line 118, dir doesn't exist), "keep the two backends' APIs aligned" (line 200), "Swappable backends (bump, love)" (line 268). Keep only `src/physics/bump/`.
- [x] `ARCHITECTURE.md` — update module tree (§2) to include `res/bg/`, `res/editor/`, `src/npc/`, `src/ipc/`, `src/player/states/`, `src/emitters/`, `src/fx/`; add missing component types (Sound, Tint, UsableSparkle, Pushable, SpeedStreak, Flash); expand utils list (json, log, profile, settings, event_bus, asset_manager, physics_tolerance).

## Phase G — Fix CONTEXT.md + NOTES.md staleness

- [x] `CONTEXT.md` — remove 6 glossary entries for removed systems: Background prop (bush/cloud, lines 81-85), Gradient object (87-91), Cloud spawner (93-97), Wind (99-103), Depth (105-109), Proximity component (111-115). Fix exit-door inconsistency (line 199 "actor_count not wired" vs line 341 "counter reaches zero or all_cages_unlocked") to match code (both paths live, only event path driven).
- [x] `NOTES.md` — add a completion note header marking the TMX→TMJ migration plan as completed (all TASKS.md items `[x]`), or archive/append completion summary.

## Phase H — Verify

- [x] Run `./test-unit.sh` and `./test-integration.sh`; confirm all tests still pass after deletions.
- [x] Update `AUDIT.md` — mark resolved items, move resolved findings from action plan, recompute metrics, update date.
