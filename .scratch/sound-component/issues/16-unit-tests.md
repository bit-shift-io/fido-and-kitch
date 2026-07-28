Status: pending

# 16: Unit Tests for Sound Component

## What to build
Comprehensive unit tests for Sound component covering init, play, pitch variation, error handling.

## Files to create/modify
- tests/unit/components/sound.unit.test.lua (new)

## Test approach
- Mock `love.audio.newSource` to return spy object
- Mock `love.math.random` for deterministic pitch variation tests
- Test: sound table parsed, sources created on init
- Test: `play(name)` clones source, sets pitch in range [1-variation, 1+variation], calls play
- Test: unknown name logs warning, no error
- Test: pitch variation = 0 produces pitch = 1
- Test: destroy cleans up sources

## Acceptance criteria
- [ ] All unit tests pass via `./test-unit.sh tests/unit/components/sound.unit.test.lua`
- [ ] Coverage: init, play, pitch variation, unknown sound, destroy

## Blocked by
01 — Sound component must exist