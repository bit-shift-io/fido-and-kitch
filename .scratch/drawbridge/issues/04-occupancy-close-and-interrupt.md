Status: pending

# Stay open while occupied, close on empty, reverse-in-place on re-trigger

## What to build

An open drawbridge stays open as long as any entity (player or enemy) overlaps its tile, and never closes on an occupant. When the last overlapping entity leaves the tile footprint, the bridge plays the close (raise) animation — the open animation in reverse — and returns to closed (deck removed, closed barrier restored). If an eligible entity re-triggers the bridge while it's closing, the animation reverses in place back toward open with no visual snap, and the deck stays/returns solid coherently.

## Files to create/modify

- src/entities/drawbridge.lua — add occupancy query over the bridge tile, the open → closing → closed transition using the reversed animation, and the closing → opening reverse-in-place interrupt; keep solidity coherent across the reversal
- tests/drawbridge_test.lua — extend

## Test approach

- Occupancy helper: given the set of colliders overlapping the bridge tile, decide stay-open vs begin-close; both players and enemies count.
- Never-drop invariant: while ≥1 entity overlaps, the state never leaves a solid-deck configuration.
- Close transition: last entity leaves → closing → closed, deck removed only after the raise completes.
- Reverse-in-place: a re-trigger mid-close flips the timeline direction and returns to open; assert direction flip and that no closed-with-occupant state occurs.
- Manual run: player crosses and the bridge raises behind them; step back mid-raise and it lowers again smoothly.

## Acceptance criteria

- [ ] Bridge stays open while any entity overlaps its tile; never drops an occupant.
- [ ] After the last entity leaves, the close (raise) animation plays and the bridge returns to closed.
- [ ] Re-triggering during close reverses in place back to open with no snap.
- [ ] Occupancy and interrupt logic covered by tests.

## Blocked by

03 (needs the open state and solid deck to close from; reuses the trigger for the interrupt).
