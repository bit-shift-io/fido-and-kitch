Status: pending

# Objective spine (keys → cages → birds → exit) + solution walkthrough

## What to build
The first true playable-but-bland level. The planner builds a solution DAG: colored keys placed in reachable zones, matching cages elsewhere, each cage wired with a generated bird path (polyline object) ending at the exit door (or an `exitInstant` exec snippet), the exit door's `actor_count` set to the bird count so releasing the last cage opens it. Key-before-cage ordering is guaranteed by construction (a key is always reachable without its own cage's reward). The tool also emits `<name>-solution.md`: ordered human steps ("P1: take the red key at …, use the red cage at …"). Demo: play the level following the walkthrough and finish it.

## Files to create/modify
- tools/level_generator/plan.lua
- tools/level_generator/walkthrough.lua
- tools/level_generator/tmx_writer.lua (object/template/path/exec emission)
- tools/level_generator/main.lua

## Test approach
Headless: plan is a valid DAG ending at exit with no circular dependencies (key never locked behind its own cage); every objective sits in a model-reachable zone at plan time; `actor_count` equals cage count; walkthrough steps correspond 1:1 to plan nodes in a valid topological order; emitted objects use the same templates/properties as hand-made maps (compare shapes against `sandbox.tmx` fixtures). Manual: complete a few seeds by following the walkthrough.

## Acceptance criteria
- [ ] Generated level completable start-to-finish by following the emitted walkthrough
- [ ] All cages must be released before the exit opens; exit opens on the last one
- [ ] Bird paths are valid polylines; birds decrement `actor_count` on exit
- [ ] No key is ever unreachable or locked behind its own cage
- [ ] Walkthrough file emitted per level, matching the plan

## Blocked by
02
