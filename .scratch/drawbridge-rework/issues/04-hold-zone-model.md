Status: done

# Hold-zone state model — the bridge can never be stuck down

## What to build

The bridge becomes simple and symmetric: walk into it and it lowers, stand on it and it stays down, step clear and it raises, change your mind mid-animation in either direction and it reverses from the current frame. Crucially, a bridge that has reopened after starting to close **still closes again** once cleared — today it never does, for the rest of the level.

Anything holds it: players, enemies, and a box the player pushes into the trigger. `allowEnemies` and the `mayOpen` eligibility predicate are removed entirely.

The model:

```
held = any entity (other than the bridge's own colliders) overlapping
       the trigger tile OR the deck tile

held      and state in (closed, closing)  -> opening
not held  and state in (open, opening)    -> closing
animation finish: opening -> open, closing -> closed
```

Starting a transition from rest plays the animation from the appropriate end; interrupting an in-flight one reverses from the current frame with no snap. `hasBeenOccupied` disappears — the flag existed only because the deck is made solid before the triggering entity arrives, and putting the lead-in trigger tile inside the continuous *hold* zone removes that problem at the source: an entity that triggered the bridge but hasn't reached the deck is still standing in the trigger tile, so it is still holding it.

Deck solidity is unchanged: solid across `opening`/`open`/`closing`, absent in `closed`. Keep `collider.walkable = true` on the deck (see `AGENTS.md` — without it a crossing player is stuck in `FallState`). Keep the generous upward height margin on the occupancy query so an entity standing on the deck is caught.

Keep the trigger `Collider` as a sensor so the zone still draws under `drawphysics`, but state is driven by per-frame overlap queries over both zones, not by its `enter` callback.

## Files to create/modify

- `src/entities/drawbridge/drawbridge.lua` (hold query over both zones; symmetric transitions; `hasBeenOccupied` and `allowEnemies` gone; trigger `enter` no longer drives state)
- `src/entities/drawbridge/drawbridge_support.lua` (`mayOpen` deleted; `nextStateOnTrigger` + `nextStateOnOccupancyChange` collapse into one hold-driven transition function; `hasOccupant` generalised across both zones)
- `res/templates/drawbridge.tx` (`allowEnemies` removed)
- `res/map/sandbox.tmx`, `res/map/sandbox.lua` (`allowEnemies` removed, kept in sync)
- `res/map/drawbridge_fixture.lua` (`allowEnemies` removed)
- `tests/unit/drawbridge_test.lua` (`mayOpen` tests deleted; new transition table incl. the reopen path)
- `tests/integration/drawbridge_test.lua` (two eligibility scenarios deleted; a non-player-triggers scenario added)
- `tests/e2e/drawbridge_test.lua` (the reopen scenario extended past `opening`)
- `CONTEXT.md` (already rewritten during planning — check it still matches what shipped)

## Test approach

The regression that matters is the one the current suite misses. `tests/e2e/drawbridge_test.lua`'s `the bridge closes once the last occupant leaves, and a re-trigger mid-close reverses back to open` stops asserting the instant it sees `opening` — precisely where the bug begins. Extend it: after the reopen, walk the player clear of the footprint again and assert the bridge reaches `closed`. That extension **should fail against the current implementation** — write it first and watch it fail, or the fix isn't pinned.

Unit tier covers the transition table exhaustively, including `open -> closing -> opening -> open -> closing`, which is unreachable today.

Integration tier covers the eligibility removal behaviourally: a non-player entity entering the trigger opens the bridge. Keep `once open, an enemy can cross the deck without falling` and `every drawbridge resets to closed on level restart`; delete the two `allowEnemies` scenarios along with the property.

Watch the wrong-side e2e scenario for a false failure: its comment already notes a falling player can drift into the correct-side trigger mid-air. Under continuous hold that overlap now opens the bridge rather than being a harmless one-shot miss. The player is already committed to the kill zone below by then, so the scenario's existing `x > GAP_END_X` guard should still hold — but if it goes red, fix the assertion window, do not weaken the model.

## Acceptance criteria

- [ ] `hasBeenOccupied`, `allowEnemies` and `mayOpen` appear nowhere in the source, data files or tests.
- [ ] Held lowers the bridge from `closed` or `closing`; unheld raises it from `open` or `opening`.
- [ ] Both interruptions reverse from the current frame with no snap.
- [ ] A bridge that reopens mid-close closes again once cleared — asserted in e2e and in the unit tier.
- [ ] An entity standing in the trigger tile holds the bridge down without ever reaching the deck.
- [ ] Any entity on the deck holds it down, including one that could not have opened it under the old rules.
- [ ] A pushed box entering the trigger opens the bridge.
- [ ] Deck is solid across `opening`/`open`/`closing`, absent in `closed`; a crossing player never enters `FallState` on it.
- [ ] Wrong-side approach still falls into the exposed gap.
- [ ] Every drawbridge still resets to closed on level restart.
- [ ] The trigger zone still draws under `love . drawphysics map=drawbridge_fixture.lua`.
- [ ] All three test tiers pass, and the sandbox drawbridge is playable with no stuck-down state reachable.

## Blocked by

02 — shares the same source and data files. (Independent of 03, but sequencing after it keeps the diffs reviewable.)
