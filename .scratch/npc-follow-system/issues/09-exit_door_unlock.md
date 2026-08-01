Status: pending

# 09: Exit Door Enabled by All-Cages-Unlocked Event

## What to build
Exit door entity listens for `all_cages_unlocked` event, sets `usable = true`, adds visual feedback (glow/open). Initially `usable = false`.

## Files to create/modify
- Modify: `src/entities/exit_door.lua` (or whatever the exit entity is named)
- Test: `tests/unit/exit_door_unlock.unit.test.lua`

## Interfaces
- Consumes: `EventBus.on("all_cages_unlocked", handler)`
- Produces: `self.usable = true`; visual state change

## Test approach
- Unit test: initial `usable = false`
- Unit test: on `all_cages_unlocked` event → `usable = true`
- Unit test: event handler cleans up on entity destroy
- Integration: unlock all cages in test map, verify door usable

## Acceptance criteria
- [ ] `init`: `self.usable = false`, subscribes to `all_cages_unlocked`
- [ ] Handler: `self.usable = true`; triggers visual (e.g., `self.sprite:setAnimation("open")` or tint)
- [ ] `update(dt)`: if `usable` and player overlaps → trigger level complete (existing logic)
- [ ] `destroy`/`queueRemove`: unsubscribes from event
- [ ] Works with existing exit door win condition

## Blocked by
- Issue 08: InGameState emits `all_cages_unlocked`