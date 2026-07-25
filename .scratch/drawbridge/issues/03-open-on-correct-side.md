Status: pending

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

- [ ] Correct-side player approach triggers the open animation and a solid deck.
- [ ] The deck becomes solid before the player reaches the gap (no fall).
- [ ] Wrong-side approach does not open the bridge.
- [ ] Once open, the deck is solid ground the player crosses.
- [ ] Trigger sensor and open behaviour mirror correctly with `facing`.
- [ ] New helpers covered by tests.

## Blocked by

01 (reversible Timeline API for the open/close animation), 02 (drawbridge entity + closed state + fixture).
