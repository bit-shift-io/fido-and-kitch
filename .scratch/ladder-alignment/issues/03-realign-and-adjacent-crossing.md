Status: pending

# Re-align to nearest + adjacent-ladder crossing

## What to build

After sliding off-centre, pressing up/down re-enters the `aligning` mode and slides the player back onto the nearest overlapping ladder's centre-x — at the **slow** slide speed (not walk speed; walk speed is only the initial mount from the ground) — then resumes climbing. When the player straddles two touching ladders, "nearest centre" commits to whichever ladder they are mostly over.

This closes the loop and makes two side-by-side ladders traversable: climb ladder A, hold toward B to slide across the seam onto B (still on a ladder, no fall), press up/down to re-centre on B, and climb B.

Distinguish the two alignment speeds: initial mount (from the ground, issue 01) = walk speed; any re-align while already in `LadderState` = slow speed. The `aligning` mode needs to know which case it is.

## Files to create/modify
- src/player/player_states.lua — allow `sliding` → `aligning` on a new up/down press; parameterise `aligning` speed (walk on initial mount, slow on re-align); resume `climbing` after re-centre.
- src/player/player_movement.lua — reuse the nearest-ladder-centre seam from issue 01 for re-align target selection over the set of currently-overlapping ladders.
- Test file — extend the fast headless regression tests for the straddle/nearest case.

## Test approach
- Unit-test that with the player straddling two adjacent ladders, nearest-centre picks the ladder whose centre is closest to the player centre-x (test both sides of the seam).
- Decision-level check: after a slide leaves the player off-centre over ladder B, an up press produces a slow horizontal velocity toward B's centre, then vertical climb once centred.
- Manual/integration demo in the sandbox map: place two touching ladders and confirm end-to-end crossing.

## Acceptance criteria
- [ ] Pressing up/down after sliding re-aligns to the nearest overlapping ladder's centre at the slow speed, then climbs.
- [ ] Re-align uses slow speed; only the initial ground mount uses walk speed.
- [ ] Straddling two touching ladders and pressing up/down commits to the nearer ladder.
- [ ] Two side-by-side ladders can be crossed end-to-end: climb one, slide across, re-centre, climb the other.

## Blocked by
Issues 01, 02.
