Status: pending

# 04-e2e-tests

## What to build
Headed end-to-end tests with real LÖVE window, rendering, and frame capture to verify visual correctness of speech bubbles.

## Files to create/modify
- tests/e2e/story_entity.e2e.test.lua
- tests/fixtures/maps/story_e2e.lua (map with 3-4 story entities)

## Test approach
Use `test-e2e.sh` (real LÖVE, real window, frame capture). Test scenarios:
- Launch map, verify entities render (invisible sensor, no visual by default)
- Move player to entity 1, press use key → capture frame, verify bubble appears above entity with correct text
- Move camera (walk player) → capture frame, verify bubble follows entity on screen
- Walk player away → capture frame, verify bubble gone
- Rapid use key presses → verify cooldown blocks re-trigger
- Multiple entities in level → each works independently
- Co-op: P1 triggers entity 1, P2 triggers entity 2 simultaneously → both bubbles visible (or documented behavior)

## Acceptance criteria
- [ ] Test file runs with `./test-e2e.sh tests/e2e/story_entity.e2e.test.lua`
- [ ] Frame captures show bubble at correct world→screen position
- [ ] Bubble follows entity during camera movement
- [ ] Text renders correctly with line breaks
- [ ] Cooldown visually verified (no flicker on rapid press)
- [ ] Multiple entities work in same level

## Blocked by
01-story-entity-core, 02-unit-tests, 03-integration-tests