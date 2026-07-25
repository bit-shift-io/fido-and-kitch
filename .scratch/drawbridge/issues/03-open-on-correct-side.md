Status: in-progress — blocked on a real repro-ability problem, see notes below

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
- [ ] Wrong-side approach does not open the bridge. (implemented — no sensor exists on the wrong side by construction — but not yet re-verified after the fixes below)
- [ ] Once open, the deck is solid ground the player crosses. **Player gets stuck partway across — see below.**
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
