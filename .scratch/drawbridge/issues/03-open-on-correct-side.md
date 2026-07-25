Status: done — the repro-ability problem below is resolved; both remaining acceptance criteria are now covered by an automated headed test (see notes below)

# Open on correct-side player approach, cross the solid deck

## What to build

When a player (eligibility is hard-coded to players-only in this slice) approaches a closed drawbridge from its correct side, the bridge plays the open (lower) animation and becomes solid, walkable ground: the deck collider turns solid and the closed barrier is removed, so the player walks straight across the gap without falling. A player approaching from the wrong side does not trigger opening and remains blocked. Opening is driven by the player's collider overlapping a correct-side **trigger sensor** positioned (and mirrored) by `facing`, and the deck lowers before the player reaches the gap.

## Files to create/modify

- src/entities/drawbridge.lua — add the trigger sensor (correct side, mirrored by `facing`), a state machine closed → opening → open, the open animation via the reversible Timeline API (from 01), and the solidity flip (deck solid + barrier removed on open)
- tests/drawbridge_test.lua — extend
- res/map/<fixture>.lua — reuse fixture from 02

## Test approach

- Eligibility/trigger helper: a player overlapping the correct-side sensor starts an open; overlapping from the wrong side does not; a non-player overlap does not (players-only this slice).
- Solidity mapping helper: in `open` the deck is solid and the barrier is absent; in `closed` the reverse.
- Transition helper: closed → opening → open advances correctly and only completes when the open animation finishes.
- Manual run: player crosses from the correct side; player from the wrong side is blocked.

## Acceptance criteria

- [x] Correct-side player approach triggers the open animation and a solid deck.
- [x] The deck becomes solid before the player reaches the gap (no fall).
- [x] Wrong-side approach does not open the bridge. Re-verified by `tests/e2e/drawbridge_test.lua` — the trigger genuinely never fires from the wrong side once the barrier fix below makes it actually block.
- [x] Once open, the deck is solid ground the player crosses. Root cause of the "stuck partway across" bug found and fixed (see below); now covered by `tests/e2e/drawbridge_test.lua`.
- [x] Trigger sensor and open behaviour mirror correctly with `facing`.
- [x] New helpers covered by tests (`mayOpen`, `nextStateOnTrigger`, `nextStateOnAnimationFinish`).

## Blocked by

01 (reversible Timeline API for the open/close animation), 02 (drawbridge entity + closed state + fixture).

## Implementation notes and open problem

**Bug found and fixed while wiring the trigger:** the collider `enter` callback (used for the correct-side trigger sensor, same mechanism as `ladder`/`switch`/`jump_pad`) must be wired with `utils.func(fn, self)`, not `utils.forwardFunc(fn, self)`. `forwardFunc` is `function(oldSelf, ...) return fn(newSelf, ...) end` — it silently **drops** the single argument a collider's `enter`/`exit` handler receives (the *other* collider), because that argument arrives as `oldSelf`, not as part of `...`. `ExitDoor:contact` happens to get away with this because its body is empty and never reads `other`; `jump_pad.lua`'s `Usable{use=utils.func(...)}` is the correct precedent. Fixed in `src/entities/drawbridge.lua` for both the `enter` and `finish` wiring (the latter didn't strictly need it since `finish` takes no args, but consistency).

**Confirmed via a temporary live debug readout** (title-bar logging of player x/y/vx and drawbridge state/collider-sensor flags, removed again after — not committed) that the state machine itself works correctly:
- Player walks from spawn, crosses the trigger sensor, state goes `closed → opening → open`.
- `barrier.sensor` flips to `true` (removed) and `deck.sensor` flips to `false` (solid) at the moment of trigger, before the player reaches the gap — no fall, matches the "lead-in" design in HANDOFF.md.

**Unsolved: the player stops moving partway across the now-solid deck.** With the bridge fully `open`, deck solid, barrier removed, holding the movement key does not advance the player any further once they're standing at roughly the tile's own centre (measured at world x≈139.7, tile spans x=128..160) — velocity reads 0 even mid-hold, confirmed on a clean session (no stale input-focus dialog, clicked directly into the game window first). This is **not** at a tile seam (deck-to-right-ground boundary is at x=160, well past the stall point), so the leading theories going in were tile-seam/adjacent-static-collider artifacts — ruled out. Was mid-way through reading `src/physics/bump/motion.lua` (`Motion.resolveCollisions`) for a bug when work paused here.

**Known environment gotcha that cost significant time and is *not* the bug above:** the installed `love` binary is 11.5 but `conf.lua` targets `t.version = "12.0"`, so LÖVE sometimes shows a native "Compatibility Warning" alert on launch. It's a separate OS-level window; dismissing it via the Accessibility API (`System Events click button "OK"`) rather than a real mouse click can leave the game window unable to receive synthesized keyboard input afterward, which looks exactly like "player frozen" and cost a lot of debugging time before being ruled out. If automating manual verification again: click into the game window with a real synthesized click (`cliclick`, not `osascript`'s accessibility click) before sending key events, and do it on a fresh launch.

**Decision:** paused here to build the `.scratch/integration-testing/` harness first (real `Game`/`Map`/`Player` stack, headless `love` mock, scripted input, fixed timestep) so this kind of movement bug is caught by a deterministic assertion instead of screenshot/AppleScript archaeology. Resume this issue once that harness exists.

## Resolution (via `.scratch/headed-e2e-tests/`)

Both problems above are now root-caused and fixed, verified by the headed e2e scenario in `tests/e2e/drawbridge_test.lua` rather than manual screenshot/AppleScript archaeology:

- **"Stuck partway across" root cause:** `Player:queryOnGround()` and `GroundSupport.isFullySupported()` both only recognise a collider as "ground" when it has no owning entity (`c.entity == nil`) — correct for plain map terrain, but the drawbridge's deck collider belongs to the `Drawbridge` entity, so it was never recognised as ground at all. The player's FSM transitioned to `FallState` the instant they stepped onto the open deck and never transitioned back (vertically supported by real physics, but the FSM didn't know it), and `FallState` doesn't apply horizontal movement input — hence "stuck", not falling. Fixed with an explicit `collider.walkable` opt-in flag (set on the deck in `src/entities/drawbridge.lua`), read by both ground checks; `src/physics/bump/world.lua`'s query-result mirroring (`v.entity = v.other.entity`) was extended to mirror `.walkable` the same way, since query results are new tables, not the original collider objects.
- **Wrong-side approach never actually blocked:** the closed barrier collider reused the bridge tile's own flush-with-ground rect (same height, same top edge as the walking surface). Two solid rects of equal height that both start at the ground surface resolve as a walkable step under this project's simple AABB collision (`lib/bump`), not a wall — so the barrier never stopped a player approaching at normal standing height, from either side. This was never caught because the correct-side approach always hits the trigger (which sits closer to spawn than the barrier) before reaching the barrier, and the wrong-side case was never verified for real. Fixed by giving the barrier its own taller collider shape (5x the tile height, bottom flush with the tile, extending upward) in `src/entities/drawbridge.lua`, distinct from the deck's shape.

Both fixes are narrowly scoped to the drawbridge/ground-support code paths they touch and were verified against the existing headless suites (`./test-unit.sh`, `./test-integration.sh`) to introduce no regressions there.

## Further revision: the barrier itself was removed (post-playtesting)

After the above shipped and was playtested live, the "wrong-side approach leaves the player blocked" behaviour was reversed — see DECISIONS.md Q4's revision and `issues/02-closed-drawbridge-blocks.md`'s superseded note. **There is no barrier collider at all now.** Closed means the gap is fully exposed; the wrong side is a real hazard (fall in), not a wall.

Removing the barrier immediately surfaced the *exact* two bugs described above, again, in a new guise, while rewriting the e2e wrong-side test to expect a fall instead of a block:

- `Player:queryOnGround()`/`GroundSupport.hasGroundAt()`'s `walkable` check didn't look at the collider's *current* `sensor` state, only its permanent `walkable` flag — so a player walking over the (now correctly non-solid) closed deck was still treated as grounded and walked straight across at a fixed height instead of falling through. Fixed by additionally requiring `not collider.other.sensor` in both checks.
- The fixture map's declared `height` (6 tiles) was shorter than its own kill zone, so the map's own invisible bottom-boundary wall physically stopped the fall exactly at the kill zone's top edge, before the fall ever reached the zone's interior — the player just hung there, alive, never dying. Fixed by growing the fixture map's declared height.

Both are documented as general gotchas (not drawbridge-specific) in `tests/README.md`. The e2e wrong-side test (`tests/e2e/drawbridge_test.lua`) now asserts the player falls into the gap and the bridge never opens while still approaching on solid ground (a mid-air drift into the correct-side trigger while already falling is possible and harmless, since they're already committed to the fall — not asserted against).
