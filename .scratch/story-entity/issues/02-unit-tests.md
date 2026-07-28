Status: pending

# 02-unit-tests

## What to build
Unit tests for the story entity covering initialization, collider setup, state machine logic, and cooldown behavior — no LÖVE window, no map loading.

## Files to create/modify
- tests/unit/story_entity.unit.test.lua

## Test approach
Use existing unit test framework (`test-unit.sh`). Mock `Entity`, `Collider`, `Camera`, `world.players`. Test pure Lua logic:
- `StoryEntity:init(props)` stores `props.text`
- Collider created with `sensor=true, solid=false, walkable=false`
- `update(dt)` with overlapping player + usePressed → `showing = true`
- `update(dt)` with non-overlapping player → `showing = false`, cooldown starts
- Cooldown decrements each frame; re-trigger blocked while > 0
- Text with `\n` preserved for rendering

## Acceptance criteria
- [ ] Test file created and runs with `./test-unit.sh tests/unit/story_entity.unit.test.lua`
- [ ] All tests pass
- [ ] Coverage: init, collider props, trigger logic, dismiss logic, cooldown

## Blocked by
01-story-entity-core (needs entity implementation)