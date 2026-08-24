# PLAN - Ladder remodel: no-gravity zone + standable top (NOTES.md)

Remodel ladders as a no-gravity volume that auto-catches falling players and
gains a standable one-way top — fixing side-entry fall-through. Confirmed
decisions live in `NOTES.md` (2026-08-24 grill).

## Tasks

- [x] 1. RED integration test `tests/integration/ladder_catch_test.lua`: fixture-map player falling into a ladder column enters LadderState mid-fall (hangs, no gravity); grounded walkthrough of the same column stays WalkIdleState.
- [x] 2. GREEN auto-catch + entry mode: add fall-catch check to FallState:update and pick LadderState initial mode from held input (up/down → aligning; none → climbing/hang) — `src/player/player_states.lua` (+ pure `resolveEntryMode` helper + unit test in `src/player/player_movement.lua`, `tests/unit/player_movement_test.lua`).
- [x] 3. Verify alignment carve-out in `tests/integration/ladder_catch_test.lua`: falling in while holding left/right never slides to centre-x; pressing up/down later does.
- [x] 4. RED integration test `tests/integration/ladder_top_test.lua`: player stands on a bare ladder top with NO terrain beneath (`queryOnGround` true), walks across it, and does not mount/climb-pose while standing there.
- [x] 5. GREEN one-way top platform on lead rung in `src/entities/ladder.lua`: thin top-edge collider using mover_platform one-way colFilterFn pattern + `walkable = true`; rebuilt by resizeTileHeight/grow/show, removed by hide (store as its own component so hide() clears it).
- [x] 6. Extend `tests/integration/ladder_top_test.lua`: press down while standing on the bare top descends into the ladder (mount-down via queryLadderBelow probe).
- [x] 7. Extend switch coverage `tests/integration/ladder_switch_test.lua`: switch-off ladder neither catches a falling player nor supports standing (no collider, no top); switch-on restores both, keeping grown size.
- [x] 8. NPC regression check `tests/integration/npc_ladder_test.lua`: spider/robot still climbs a remodeled ladder opportunistically and rabbit breadcrumbs through it; patch minimally only if broken (then touch `src/npc/` files). [No spider/robot ladder-climbing exists in the codebase — honored NOTES' verify-only intent: rabbit pass-through integration test + top-slab wiring pin in unit tier.]
- [x] 9. Docs: update CONTEXT.md glossary entries (ladder mount alignment, ladder slide — no-gravity zone, auto-catch, one-way top) + README.md authoring note (terrain under ladder tops now optional).
- [x] 10. Full validation: `./test-unit.sh && ./test-integration.sh`; then manual watch `./run.sh map=ladder` (side-entry catch, bare-top standing, down-to-descend, switch-off behaviour).
