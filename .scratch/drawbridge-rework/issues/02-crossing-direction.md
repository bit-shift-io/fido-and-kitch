Status: done

# `facing` becomes `crossingDirection`

## What to build

A level designer placing a drawbridge in Tiled sets `crossingDirection` to `leftToRight` or `rightToLeft` — naming the direction of travel the bridge permits — and gets the trigger tile on the arrival side: `leftToRight` puts it one tile to the **left**, `rightToLeft` one tile to the **right**. Dropping the template in without touching any property gives a working left-to-right crossing.

This is a hard rename with no compatibility shim. `facing` must not survive anywhere in drawbridge code, data or docs. Gameplay is unchanged in this slice — both existing placements were `facing = "left"`, which is `leftToRight`.

The property is read once in the constructor and validated: an unknown or missing value falls back to `leftToRight` rather than erroring, so a half-edited map still loads.

Sprite mirroring is deliberately **not** touched here — the entity keeps passing whatever it passes today. Issue 03 fixes that separately, so the rename stays a rename and the visual change is reviewable on its own.

## Files to create/modify

- `src/entities/drawbridge/drawbridge.lua` (read and validate the new property)
- `src/entities/drawbridge/drawbridge_support.lua` (`triggerOffsetX` takes the new values)
- `res/templates/drawbridge.tx` (`crossingDirection` defaulting to `leftToRight`)
- `res/map/sandbox.tmx` (drop the now-redundant per-object override — the object inherits the template default)
- `res/map/sandbox.lua` (the STI export; hand-edited to match the `.tmx`)
- `res/map/drawbridge_fixture.lua` (property and comments)
- `tests/unit/drawbridge_test.lua` (offset tests renamed to the new values, plus the fallback case)
- `tests/e2e/drawbridge_test.lua` (comments referring to `facing`)

## Test approach

Unit tier carries the weight: `crossingDirection` maps to trigger offset in both directions, and an unrecognised or absent value falls back to `leftToRight`. These are pure and belong beside the existing `triggerOffsetX` tests.

Integration and e2e should pass **unchanged** — that is the proof the rename preserved behaviour. If an e2e scenario needs anything beyond a comment edit, the rename changed semantics and something is wrong.

Finish with a repo-wide grep for `facing` scoped to drawbridge files, templates and maps; the only surviving hits should be `Sprite`'s own prop and unrelated entities (players use it for genuine left/right facing).

## Acceptance criteria

- [ ] No drawbridge source, template, map, fixture, test or doc mentions `facing`.
- [ ] `res/templates/drawbridge.tx` declares `crossingDirection` with default `leftToRight`.
- [ ] `res/map/sandbox.tmx` and `res/map/sandbox.lua` agree with each other and carry no `crossingDirection` override.
- [ ] `leftToRight` places the trigger one tile left; `rightToLeft` one tile right.
- [ ] A missing or unrecognised value loads and falls back to `leftToRight`.
- [ ] All three test tiers pass; integration and e2e scenarios are unchanged apart from comments.
- [ ] The sandbox level runs and the drawbridge behaves exactly as before this slice.

## Blocked by

01 — the files it edits move in that slice.
