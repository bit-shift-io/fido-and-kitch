Status: pending

# 11: Unit + Integration Tests for NPC Follow System

## What to build
Comprehensive test coverage for all new components and entities, plus integration test for full cage→NPC→exit flow.

## Files to create/modify
- Create: `tests/unit/npc_follow.component.unit.test.lua`
- Create: `tests/unit/bird_npc.unit.test.lua`
- Create: `tests/unit/rabbit_npc.unit.test.lua`
- Create: `tests/unit/cage_spawn.unit.test.lua`
- Create: `tests/unit/player_position_history.unit.test.lua`
- Create: `tests/unit/ingame_cage_tracking.unit.test.lua`
- Create: `tests/unit/exit_door_unlock.unit.test.lua`
- Create: `tests/unit/npc_teleport.unit.test.lua`
- Create: `tests/unit/bird_switching.unit.test.lua`
- Create: `tests/unit/rabbit_navigation.unit.test.lua`
- Create: `tests/integration/npc_follow_flow.integration.test.lua`

## Test approach
- Unit tests: mock dependencies (world, players, map), test each behavior in isolation
- Integration test: load test map with 2 cages (bird + rabbit), unlock both, verify NPCs follow, exit door opens, player completes level
- Use `tests/support/game_harness.lua` for integration setup
- Use `tests/support/fake_input.lua` for player control

## Acceptance criteria
- [ ] All unit tests pass: `./test-unit.sh`
- [ ] Integration test passes: `./test-integration.sh tests/integration/npc_follow_flow.integration.test.lua`
- [ ] Coverage: steering, breadcrumbs, switching, teleport, cage spawn, event flow, exit unlock
- [ ] Tests use headless mock (no LÖVE window)
- [ ] Test map: `res/map/test_npc_follow.lua` (simple layout: spawn, 2 cages, ladders, exit)

## Blocked by
- Issues 01-10: All implementation complete