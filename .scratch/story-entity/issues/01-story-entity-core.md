Status: pending

# 01-story-entity-core

## What to build
Create the `StoryEntity` class in `src/entities/story.lua` that loads from Tiled objects with `type="story"` and a `text` property. The entity creates a sensor collider for overlap detection. When a player overlaps and presses the use key, the entity enters a `showing` state and renders a speech bubble above itself with the configured text. The bubble dismisses when the player exits the sensor. A 0.5s cooldown prevents immediate re-trigger.

## Files to create/modify
- src/entities/story.lua

## Test approach
Unit tests in `tests/unit/story_entity.unit.test.lua`:
- Entity initializes with text from props
- Sensor collider created with correct properties (sensor=true, solid=false, walkable=false)
- State transitions: idle → showing (on trigger) → idle (on dismiss)
- Cooldown timer blocks re-trigger for 0.5s
- Text property handles `\n` line breaks

## Acceptance criteria
- [ ] `StoryEntity` class extends `Entity`
- [ ] Reads `props.text` from Tiled object properties
- [ ] Creates sensor collider on init
- [ ] `update(dt)` checks player overlap + use key → shows bubble
- [ ] `update(dt)` hides bubble when player exits overlap
- [ ] Cooldown timer enforced after dismiss
- [ ] `draw()` renders speech bubble at camera-relative position above entity
- [ ] Text renders with `\n` as line breaks

## Blocked by
None — can start immediately