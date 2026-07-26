# Drawbridge Rework — Decisions

## Q1: What should the ambiguous `facing` property be called, and what should it mean?

**Decision:** `crossingDirection`, with values `leftToRight` / `rightToLeft`.

- **Why:** `facing` named the side the trigger sensor sat on, so `facing = "left"` produced a bridge you cross *left to right* — the value read as the opposite of the behaviour. Naming the direction of travel removes the inversion the reader has to perform.
- **Implication:** Every drawbridge value in the repo changes, not just the key. `facing = "left"` becomes `crossingDirection = "leftToRight"`.
- **Alternatives considered:**
  - `approachSide` (`left`/`right`) — honest about today's semantics and a smaller diff, since the values wouldn't change. Rejected: still names a side, so a designer still has to translate side into direction.
  - `crossing` — same semantics, shorter. Rejected as marginally less explicit for no real gain.

## Q2: How should `crossingDirection` drive the sprite?

**Decision:** Invert the current mapping. `leftToRight` renders the sprite unmirrored; `rightToLeft` mirrors it. The entity maps explicitly to `Sprite{facing = ...}` rather than passing the property through.

- **Why:** The art is a tower hinged on the left with the deck lowering rightward, drawn two tiles wide centred on the object's top-left corner — so unmirrored, the tower covers the tile to the left (where the trigger is) and the deck lands on the bridge tile. That is exactly a left-to-right crossing. Both shipped placements used `facing = "left"`, mirroring it, which put the tower over the gap and lowered the deck back over solid ground.
- **Implication:** The visual bug is fixed with no art change, and the sprite's mirror flag stops being conflated with the bridge's direction semantics.
- **Alternatives considered:**
  - Re-reading the art as hinged-right — rejected after inspecting the sprite sheet and the sprite's placement maths.
  - Mirroring the source PNG and leaving the code mapping alone — rejected: it fixes the render while leaving one property doing two jobs, and breaks anything already tuned to the sheet.

## Q3: Why does the bridge get stuck down?

**Decision:** The `hasBeenOccupied` guard is the cause, and it is removed rather than patched.

- **Why:** `hasBeenOccupied` existed because the deck is deliberately made solid *before* the triggering entity physically arrives, so a freshly-opened bridge would otherwise see `occupied == false` and immediately reverse. It is set `false` the moment closing starts and never restored on a reopen — so any bridge that reopens mid-close (trigger re-entry, or an occupant reappearing) can never take the `open -> closing` edge again. It stays down for the rest of the level.
- **Evidence:** The full test suite passes today, including e2e `the bridge closes once the last occupant leaves, and a re-trigger mid-close reverses back to open` — but that scenario stops asserting the instant it observes `opening`, which is precisely where the bug begins. The bug is reachable in free play by crossing, turning back near the deck, and walking off.
- **Implication:** The regression test must extend past the reopen, not merely exist.
- **Alternatives considered:**
  - Reset the flag only when the bridge reaches `closed` — the minimal fix, and it does resolve the reopen lockout. Rejected in favour of the simpler model in Q4, which needs no flag at all.
  - Arm the bridge on a grace timer after opening — rejected as a second timing mechanism to tune and test.

## Q4: What is the state model?

**Decision:** A symmetric hold-zone model. `held` = any entity overlapping the trigger tile or the deck tile. Held pushes toward open, unheld toward closed; either transition reverses an in-flight animation from the current frame.

- **Why:** Stated by the user as the desired behaviour: touch it and it lowers, stand on it and it stays down, get off and it raises, reverse direction mid-animation and it reverses in place. "There is no need for anyone to use it" — the *has anyone been on it yet* concept disappears from the design, not just the code.
- **Key insight:** Making the lead-in trigger tile part of the continuous *hold* zone — rather than a one-shot `enter` event — is what makes the guard unnecessary. An entity that triggered the bridge but hasn't reached the deck yet is still standing in the trigger tile, so it is still holding the bridge down. The failure mode the flag existed to prevent cannot occur.
- **Implication:** State is driven by per-frame overlap queries over both zones. The trigger `Collider` is retained as a sensor purely for `drawphysics` visibility; its `enter` callback no longer drives anything.
- **Trade-off accepted:** Two overlap queries per bridge per frame instead of one plus an event. Negligible at the scale of one or two bridges per level, and it buys a state machine with no hidden memory.

## Q5: Who can open the bridge, and who can hold it down?

**Decision:** Anything. `allowEnemies` and the `mayOpen` eligibility predicate are both removed.

- **Why:** The user's reasoning: a player pushing a box into the drawbridge should open it — that is, the *box* triggers the bridge. Once props are eligible, an allowlist of types is a maintenance burden that will be wrong again the next time an entity type is added. "Anything that pushes into the trigger pushes down the drawbridge to open it."
- **Implication:** Two integration tests asserting players-only and the `allowEnemies` opt-in are deleted, and the property is removed from the template, sandbox and fixture. A patrolling enemy can now hold a bridge permanently down; that is accepted as a level-design concern, not the entity's.
- **Alternatives considered:**
  - Keep `allowEnemies` and add `push_box` to the eligible types — rejected; the allowlist keeps growing.
  - Leave the predicate commented out as a way back — rejected; dead code, and git history is the way back.

## Q6: Should `drawbridge_support.lua` be merged into `drawbridge.lua`?

**Decision:** No — keep them separate, with a comment explaining why, and move both into a directory named after the entity.

- **Why:** The original ask was a single file, but `tests/unit/` is pure Lua with no LÖVE surface at all, and `drawbridge.lua` evaluates `Class{__includes = Entity}` and constructs `Sprite`/`Collider` at require time. Merging would push the decision-logic tests down to the integration tier (slower, LÖVE-mock dependent) or force fragile global stubbing in the unit tier. The split mirrors `src/player/ground_support.lua`.
- **Implication:** The comment is load-bearing — without it, the split looks arbitrary and someone merges it back. The real problem the user was reporting (two loose sibling files, no visible relationship) is solved by the directory instead.
- **Alternatives considered:**
  - Merge and stub `Class`/`Entity`/`Sprite`/`Collider` in the unit test — rejected as fragile; it breaks whenever the entity's construction changes.
  - Merge and move the tests to integration — rejected; it trades a fast tier for a slower one to satisfy a file-count preference.

## Q7: How are files named inside `src/entities/drawbridge/`?

**Decision:** Keep the existing filenames — `drawbridge.lua` and `drawbridge_support.lua` — inside the directory. No `init.lua`.

- **Why:** The user's reasoning: "keep the current file names so we know what we are editing with a nice filename. init.lua and support.lua are too generic." Editor tab bars and stack traces show the filename, not the directory.
- **Implication:** `require('src.entities.drawbridge')` no longer resolves on its own, so the loader has to learn the convention (Q8).
- **Note:** `init.lua` in Lua is not quite a JavaScript barrel file — it's the package system's directory-entry convention: `require('a.b')` falls back to `a/b/init.lua` automatically. It *can* re-export like a barrel, but here it would only ever be a one-line stub.
- **Alternatives considered:** `init.lua` + `support.lua` (standard Lua, zero loader change) — rejected on the generic-names objection above.

## Q8: How does the entity loader find a nested entity?

**Decision:** Make `Map`'s `searchPaths` pattern-based and add `src.entities.?.?` alongside `src.entities.?`.

- **Why:** Declares the convention once, in the loader, so every future multi-file entity works with no stub file and no per-entity special-casing. Resolution stays the existing `pcall(require, ...)` loop; first success wins.
- **Implication:** With a second candidate now normal, the per-candidate `Entity Error:` print becomes noise on every successful nested load — it must only report when all candidates fail. (That print is already noisy today; the integration run shows a full `package.path` dump for `push_box`.)
- **Alternatives considered:** A one-line `init.lua` re-export per entity — zero loader risk, rejected because every future multi-file entity carries a stub file.

## Q9: Backwards compatibility for the old properties?

**Decision:** None. Hard rename, all data files updated in the same change.

- **Why:** Three in-repo placements (template, sandbox, fixture) and no external map authors. A compatibility shim would outlive its usefulness immediately.
- **Implication:** `res/map/sandbox.tmx` (Tiled source) and `res/map/sandbox.lua` (STI export) must both be edited and kept in sync by hand. The template default becomes `leftToRight`, which makes the sandbox object's override redundant — it is dropped, and the object inherits the template.

## Q10: How big is the sprite, and where is it centred?

**Decision:** 3×3 tiles, centred on the object tile — one tile of visual bleed in every direction — while the colliders stay one tile.

- **Why:** The user's reasoning: the extra ring lets the art be overlaid on the surrounding tiles so the bridge integrates into the environment instead of stopping dead at the tile border. Masonry can key into the ground, the tower can break the grid, animation can spill past the deck.
- **What it replaces:** Today's framing is a 2×2 box centred on the object's **top-left corner** — asymmetric, covering the bridge tile plus the tiles above, left, and above-left. Nothing depended on that asymmetry; it appears to be incidental.
- **Implication:** Visual footprint and physical footprint now differ by design. That has to be stated plainly in the glossary and in comments, because "the sprite covers this tile" stops being a safe inference about what you can stand on.
- **Derivation:** Sized from `3 * object.width` / `3 * object.height`, not a hard-coded 96, so it survives a tile-size change.
- **Layering:** Overlapping neighbours requires the sprite to draw above the tile layers. It already does — the entity object layer sits after every tile layer in the Tiled layer order — so this is a level-authoring constraint to know, not a code change.

## Q11: The sheet is 64×64 frames but the 3×3 box is 96×96. What happens in between?

**Decision:** Land the geometry now and accept a temporary 1.5× stretch; redraw the sheet at 4 frames of 96×96 (`384×96`) as a separate follow-up.

- **Why:** Chosen by the user to unblock the code. The stretch is non-integer and will look soft on pixel art, but nothing in the code hard-codes either size, so the redraw is a drop-in later.
- **Implication:** Issue 03's capture review judges *orientation and framing*, not art quality — the softness is expected and is not a defect to chase. The redrawn sheet does not need a code change to land.
- **Alternatives considered:**
  - Wait for 96×96 art before writing the geometry — cleanest review, rejected because it blocks the code on an art task.
  - Pad the existing 64×64 content into transparent 96×96 frames to keep 1:1 pixels — no stretch and no new art, rejected because it bakes the old composition into a new sheet that is about to be redrawn anyway.

## Assumptions

- The Tiled `.tmx` and its exported `.lua` are maintained by hand in this repo; there is no export step to re-run.
- `res/map/drawbridge_fixture.lua` is a test fixture, not a shipped level, so its geometry is free to stay exactly as it is — only the properties change.
- The e2e tier's captures are reviewed by a human; the sprite-orientation fix is verified by capture, not by an automated pixel assertion.
- Nothing outside the drawbridge reads `allowEnemies` or a drawbridge's `facing`.

## CONTEXT.md updates

- **Drawbridge** — entry rewritten. Beyond the rename, the existing text was already out of date: it claimed a closed bridge "blocks passage like a wall so no one falls by bumping it", whereas the code (and the e2e test) make a closed bridge leave the gap fully exposed. The eligibility sentence is dropped along with the property.
- **Reversible timeline** — unchanged; the hold-zone model uses the same reverse-from-current capability it already documents.
