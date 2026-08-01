Status: pending

# 08: InGameState Tracks Cages, Emits All-Unlocked Event

## What to build
`InGameState` counts total cages on map load, listens for `cage_unlocked` events, increments counter, emits `all_cages_unlocked` when count reaches total.

## Files to create/modify
- Modify: `src/states/ingame_state.lua`
- Test: `tests/unit/ingame_cage_tracking.unit.test.lua`

## Interfaces
- Consumes: `EventBus.on("cage_unlocked", handler)`, `map` (to count cages on load)
- Produces: `EventBus.emit("all_cages_unlocked", {totalCages=N})` when all unlocked

## Test approach
- Unit test: on `load(map)`, counts cages via `map:getEntitiesByType("cage")`
- Unit test: each `cage_unlocked` increments counter
- Unit test: when counter == total, emits `all_cages_unlocked`
- Unit test: event payload includes `totalCages`
- Integration: unlock all cages in test map, verify event fires

## Acceptance criteria
- [ ] In `load(map)`: `self.totalCages = #map:getEntitiesByType("cage")`, `self.unlockedCages = 0`
- [ ] Subscribes to `cage_unlocked` in `load`, unsubscribes in `unload`/`leave`
- [ ] Handler: `self.unlockedCages = self.unlockedCages + 1`
- [ ] If `self.unlockedCages == self.totalCages`: `EventBus.emit("all_cages_unlocked", {totalCages=self.totalCages})`
- [ ] Handles edge case: 0 cages in level → emits `all_cages_unlocked` immediately on load

## Blocked by
- Issue 07: Cage emits `cage_unlocked` event