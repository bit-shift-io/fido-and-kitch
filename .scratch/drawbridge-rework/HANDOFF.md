# Drawbridge Rework — Handoff

## Summary

Four related pieces of work on the shipped drawbridge. Its two source files move into `src/entities/drawbridge/` (keeping their real filenames) with the entity loader taught the directory convention; the ambiguous `facing` Tiled property becomes `crossingDirection` with `leftToRight` / `rightToLeft` values that name the travel the bridge permits; the sprite is reframed to 3×3 tiles centred on the object tile and its mirroring — currently inverted, so both shipped bridges draw the tower over the gap — is fixed by mapping direction to sprite facing explicitly; and the state machine is replaced with a symmetric hold-zone model that removes the `hasBeenOccupied` flag, the `allowEnemies` property and entity-type eligibility altogether.

The one live bug is the last of those: `hasBeenOccupied` is cleared when closing starts and never restored on a reopen, so any bridge that reverses back to open can never close again for the rest of the level. Note that **the entire current test suite passes** — the e2e scenario that would catch it stops asserting exactly one state transition too early. Don't take a green suite as evidence the bug isn't there.

## Suggested implementation order

1. **[01 — entity directory](issues/01-entity-directory.md)** — first, because every later slice edits files this one moves. Pure move plus a loader capability; the existing suite passing unchanged is the whole proof.
2. **[02 — crossingDirection](issues/02-crossing-direction.md)** — the rename on its own, deliberately *not* touching sprite mirroring. Both shipped placements were `facing = "left"` = `leftToRight`, so behaviour is unchanged and integration/e2e passing unedited is the proof.
3. **[03 — sprite framing and orientation](issues/03-sprite-framing-and-orientation.md)** — both visual changes together (3×3 centred footprint, and the mirror mapping), isolated so they can be reviewed from captures without a rename in the diff.
4. **[04 — hold-zone model](issues/04-hold-zone-model.md)** — the behaviour change and the bug fix, last and largest. Independent of 03; sequenced after it only to keep diffs reviewable.

## Documents

- [PRD.md](PRD.md) — requirements, the full state model, testing decisions, acceptance criteria.
- [DECISIONS.md](DECISIONS.md) — the grill Q&A: why the files stay split, why the mapping is inverted, why eligibility is gone.
- [docs/adr/0003-multi-file-entity-directories.md](../../docs/adr/0003-multi-file-entity-directories.md) — the entity directory convention and the loader change. Constrains issue 01.
- `CONTEXT.md` — the **Drawbridge** entry is already rewritten and the new **Hold zone (drawbridge)** entry added; re-check them against what actually ships.

## Implementer notes

**Write the failing e2e assertion first in slice 04.** The extension to the reopen scenario (walk clear a second time, assert `closed`) must be seen failing against the current implementation. It is the only thing that pins the bug.

**`collider.walkable = true` on the deck is load-bearing** — see `AGENTS.md`. Without it a player stepping onto the deck is stuck in `FallState`, physically supported but unable to walk. It is only reproducible under real rendering, so the headless tiers won't warn you.

**A closed bridge is not a wall.** The gap stays fully exposed; the wrong side is a genuine hazard you fall into. `CONTEXT.md` used to claim the opposite — that has been corrected, but the old wording may have propagated into comments.

**Two sandbox representations.** `res/map/sandbox.tmx` is the Tiled source and `res/map/sandbox.lua` the STI export; both are hand-maintained here with no export step to re-run. Edit them together or the running game and the editor disagree.

**Test tier boundaries are strict.** `tests/unit/` has no LÖVE at all — that constraint is the entire reason `drawbridge_support.lua` exists as a separate file. Don't require the entity there.

**Expect one e2e scenario to wobble in slice 04.** The wrong-side approach test already notes that a falling player can drift into the correct-side trigger mid-air; under continuous hold that overlap now actually opens the bridge. The player is committed to the kill zone by then, so the existing assertion window should hold — if it doesn't, adjust the window, not the model.

**The sprite will look soft after slice 03, and that's expected.** The 3×3 box is 96×96 but the sheet is 4 frames of 64×64, so it stretches 1.5×. The sheet gets redrawn at `384×96` as a follow-up needing no code change. Judge the captures on framing and orientation, not sharpness.

**Visual footprint ≠ physical footprint from slice 03 onward.** The sprite covers 3×3 tiles; the deck and trigger stay one tile each. Don't let the bigger sprite talk you into resizing a collider to match.

**`tests/e2e/` needs a real LÖVE binary** (`bin/love.AppImage` or `love` on PATH) and takes noticeably longer than the other tiers; run it per-file (`./test-e2e.sh tests/e2e/drawbridge_test.lua`) while iterating.
