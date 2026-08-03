# Sprite Bounce (Ping-Pong) Animation Design

## Overview
Add a `bounce` mode to the Timeline component that plays animation forward to end, then reverses back to start, then forward again — creating a ping-pong/bounce effect.

## Current State
- Timeline has `loop` boolean: when true, restarts from same direction (forward→forward, reverse→reverse)
- Timeline has `isReverse` flag for direction
- Sprite uses `Timeline:getFrameIndex(frameCount)` to get current frame

## Target State
- New `bounce` property on Timeline (boolean)
- When `bounce=true` and `loop=true`: forward→end→reverse→start→forward...
- When `bounce=true` and `loop=false`: forward→end→reverse→start→stop
- Backward compatible: existing `loop` without `bounce` works as before

## Implementation

### Timeline Changes (`src/components/timeline.lua`)

1. **Add `bounce` prop** in `init`:
```lua
self.bounce = props.bounce or false
```

2. **Modify `progress()` loop logic** (around line 115-141):
- When reaching end (clock == duration) in forward direction:
  - If `bounce` and not `isReverse`: flip to reverse, continue
  - Else if `loop`: reset to start (current behavior)
  - Else: stop
- When reaching start (clock == 0) in reverse direction:
  - If `bounce` and `isReverse`: flip to forward, continue
  - Else if `loop`: set to end (current behavior)
  - Else: stop

3. **Add helper method** for direction flip:
```lua
function Timeline:flipDirection()
    self.isReverse = not self.isReverse
end
```

### Usage in Sprite
- Pass `bounce=true` in Sprite props when creating animated sprites that should ping-pong
- Example: `Sprite{ frames=4, duration=1.0, loop=true, bounce=true }`

## API
```lua
-- Ping-pong loop (forward→reverse→forward...)
Timeline{duration=1.0, loop=true, bounce=true}

-- Single bounce then stop (forward→reverse→stop)
Timeline{duration=1.0, loop=false, bounce=true}

-- Traditional loop (unchanged)
Timeline{duration=1.0, loop=true, bounce=false}
```

## Testing
- Unit test: Timeline with `bounce=true, loop=true` alternates direction at boundaries
- Unit test: Timeline with `bounce=true, loop=false` stops after one bounce cycle
- Integration: Sprite with bounce shows correct frame sequence forward then reverse

## Files to Modify
1. `src/components/timeline.lua` - core bounce logic
2. (Optional) `src/components/sprite.lua` - pass bounce prop through

## Files to Add
- None