Status: pending

# 03-integration-tests

## What to build
Integration tests that load a real map with story entities through the STI/Map pipeline and verify end-to-end trigger flow with mocked LÖVE.

## Files to create/modify
- tests/integration/story_entity.integration.test.lua
- tests/fixtures/maps/story_test.lua (minimal map with 2 story entities)

## Test approach
Use `test-integration.sh` (headless real stack). Create a minimal Tiled-exported map with:
- 2 story entities at different positions, different text
- Player spawn near first entity
Test cases:
- Map loads, both entities spawn with correct text
- Player overlaps entity 1 + use key → entity 1 showing
- Player moves to entity 2 + use key → entity 2 showing, entity 1 hidden
- Player exits entity 2 → bubble hides, cooldown active
- Cooldown expires → can re-trigger
- Two players (P1/P2) can trigger independently (if per-player tracking implemented)

## Acceptance criteria
- [ ] Test file runs with `./test-integration.sh tests/integration/story_entity.integration.test.lua`
- [ ] Map fixture loads correctly
- [ ] All trigger/dismiss/cooldown flows verified
- [ ] Co-op independence verified (or documented limitation)

## Blocked by
01-story-entity-core, 02-unit-tests