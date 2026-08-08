Status: done

# Objective spine (keys → cages → birds → exit) + solution walkthrough

## What to build
The first true playable-but-bland level. **Correction (2026-08-08, DECISIONS.md Q13):** the exit does not open via a bird/`actor_count` countdown — that mechanic (`ExitDoor:exitInstant`/`exitThroughDoor`, the `actor_count` `Variable`) is dead code, never called anywhere in the game. The real win condition is `src/states/ingame_state.lua` counting cages and emitting `all_cages_unlocked` once every cage is used, which `exit_door.lua` opens on directly. So the planner just places colored keys in reachable zones and matching cages elsewhere (also reachable); no DAG/dependency tracking is needed yet since no zone is gated by cage/key state in v1 (that arrives with rule-based gating in issue 04+) — every key and cage is simply placed in an already-reachable zone. Cages still release a bird on use (cosmetic, matches `cage.lua`'s existing "bird follows the releasing player" behaviour) but with no path/exec authoring. The tool also emits `<name>-solution.md`: ordered human steps ("P1: take the red key at …, use the red cage at …", ending in "all cages used — exit opens automatically"). Demo: play the level following the walkthrough and finish it.

## Files to create/modify
- tools/level_generator/plan.lua
- tools/level_generator/walkthrough.lua
- tools/level_generator/main.lua

## Test approach
Headless: every key and its matching cage sit in model-reachable zones; each color used exactly once (one key, one cage); walkthrough steps correspond 1:1 to the plan in a sensible order (key before its cage); emitted objects use the same templates/properties as hand-made maps (compare shapes against `sandbox.tmx` fixtures). Manual: complete a few seeds by following the walkthrough.

## Acceptance criteria
- [ ] Generated level completable start-to-finish by following the emitted walkthrough
- [ ] All cages must be used before the exit opens (verified via the game's real `cage_unlocked`/`all_cages_unlocked` mechanism, not `actor_count`)
- [ ] Every key and every cage sits in a zone the movement model reports reachable from spawn
- [ ] No key/cage color collision (each color's key and cage are a matched, unique pair)
- [ ] Walkthrough file emitted per level, matching the plan

## Blocked by
02
