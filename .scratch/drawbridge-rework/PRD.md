# Drawbridge Rework

## Problem Statement

The drawbridge shipped, but three things about it are wrong or confusing, and one of them is a live gameplay bug:

- **The code is split across two sibling files** (`drawbridge.lua` and `drawbridge_support.lua`) with nothing but a shared filename prefix tying them together. From the entity directory listing it isn't obvious they're one entity, and there's no convention for what to do when the next entity needs more than one file.
- **The `facing` property is ambiguous.** A level designer setting `facing = "left"` in Tiled gets a bridge that is crossed *left to right* — the value names the side the trigger sits on, which reads as the opposite of the travel it permits. Worse, the same value is passed straight through to the sprite as a mirror flag, so one property is silently doing two unrelated jobs.
- **The sprite renders the wrong way round.** The art is a tower hinged on the left with the deck lowering rightward. Because `facing = "left"` mirrors it, both shipped placements draw the tower standing *over the gap* and the deck lowering back over solid ground — the visual reads as a right-to-left crossing while the trigger only accepts a left-to-right one.
- **The bridge can get stuck down.** Once a bridge reopens after starting to close, it can never close again for the rest of the level.

## Solution

From the designer's side: the Tiled property is renamed to `crossingDirection` with values `leftToRight` / `rightToLeft` — it says which way you can walk over the bridge, and nothing else. The art now matches that direction, so what's drawn in the editor is what the player can do. The `allowEnemies` property disappears; anything that touches the trigger opens the bridge, including a box the player is pushing.

From the player's side the bridge becomes a simple, predictable thing: walk into it and it lowers; stand on it and it stays down; step off and it raises; change your mind mid-animation and it reverses from wherever it is. There is no longer any state in which it forgets how to raise itself.

From the codebase's side, an entity that needs more than one file gets a directory named after it, holding files that keep their real names. The drawbridge is the first one.

## User Stories

1. As a level designer, I want the Tiled property to name the direction of travel the bridge permits, so that I don't have to reason backwards from which side a sensor sits on.
2. As a level designer, I want the bridge to render facing the direction it can be crossed, so that the Tiled canvas and the running game agree.
3. As a level designer, I want a sensible default on the template, so that dropping a drawbridge in without touching properties gives me a working left-to-right crossing.
4. As a level designer, I want one fewer property to configure, so that placing a bridge is a two-decision job (where, and which way) instead of three.
5. As a level designer, I want the bridge to still be a single tile in Tiled, so that placing it stays a one-tile decision even though it draws bigger.
6. As an artist, I want the sprite to draw across the eight tiles surrounding the bridge, so that I can key the masonry and animation into the environment instead of drawing a square that stops at the tile border.
7. As a player, I want the deck to be solid before I reach the gap, so that walking at it normally never drops me in.
8. As a player, I want the bridge to stay down while I'm standing on it, so that it never raises out from under me.
9. As a player, I want the bridge to raise once I'm clear of it, so that the level resets itself behind me and the puzzle stays a puzzle.
10. As a player, I want to be able to change my mind — approach, then turn back before reaching the deck — and see the bridge raise again from wherever the animation got to, with no snapping.
11. As a player, I want to be able to change my mind the other way — turn back onto a bridge that's already raising — and have it lower again from the current frame.
12. As a player, I want a bridge I've crossed and come back to to behave exactly as it did the first time, so that nothing gets permanently stuck.
13. As a player crossing with a second player, I want the bridge held down while either of us is on it, so that the follower isn't dropped when the leader steps off.
14. As a player, I want a box I push into the trigger to open the bridge, so that props participate in the world the same way I do.
15. As a player approaching from the wrong side, I want the gap to be a real hazard I fall into, so that direction actually matters.
16. As a player, I want the bridge's bigger artwork to be purely visual, so that what I can stand on is still exactly the tile it looks like I can stand on.
17. As a designer, I want an enemy that wanders onto the deck to hold it down rather than be dropped, so that no entity is ever cut in half by a raising bridge.
18. As a developer, I want the drawbridge's files in one directory named after the entity, so that I can see at a glance what belongs to it.
19. As a developer, I want the pure decision helpers to stay in their own file with a comment saying why, so that nobody merges them back in and breaks the headless unit tier.
20. As a developer, I want the entity loader to understand the directory convention, so that the next multi-file entity needs no loader change and no stub file.
21. As a developer, I want a regression test for the reopen path specifically, so that the stuck-down bug cannot come back unnoticed.

## Implementation Decisions

### Module layout

The drawbridge moves to a directory named after the entity, with both files keeping their existing names:

```
src/entities/drawbridge/
  drawbridge.lua          -- the entity: components, wiring, state transitions
  drawbridge_support.lua  -- pure decision helpers, no LÖVE, no components
```

`drawbridge_support.lua` gains a header comment stating explicitly *why* it's a separate file — `tests/unit/` is pure Lua with no LÖVE surface at all, and the entity constructs `Sprite`/`Collider` components at require time, so the decision logic is only unit-testable while it lives apart from the entity. Merging them would silently push those tests down a tier.

### Entity loader

`Map`'s `searchPaths` becomes a list of *patterns* rather than plain prefixes, with `?` standing in for the Tiled object type:

```
self.searchPaths = {
  'src.entities.?',    -- src/entities/foo.lua
  'src.entities.?.?',  -- src/entities/foo/foo.lua
}
```

Resolution stays a `pcall(require, ...)` loop over the candidates, first success wins. The existing per-candidate `Entity Error:` print becomes noise once a second candidate is normal, so failures are only reported when *every* candidate fails.

### The `crossingDirection` property

| | Old | New |
|---|---|---|
| Property | `facing` | `crossingDirection` |
| Values | `left` / `right` | `leftToRight` / `rightToLeft` |
| Means | which side the trigger sensor sits on | the direction of travel the bridge permits |
| Template default | `right` | `leftToRight` |

No backwards compatibility for `facing` — it's a hard rename across the template, both sandbox representations, the test fixture, tests, and docs. The property is read once in the entity constructor and validated: an unknown or missing value falls back to `leftToRight`.

Trigger placement follows directly: `leftToRight` puts the trigger one tile to the **left** (you arrive from the left), `rightToLeft` one tile to the **right**.

### Sprite footprint

The bridge occupies **one tile** in Tiled and one tile of collision, but draws **3×3 tiles centred on that tile** — one tile of bleed in every direction. The extra ring is there so the art can overlap its neighbours (masonry keying into the surrounding ground, the tower breaking the tile grid, animation spilling past the deck) and read as part of the environment rather than a sticker on top of it.

This replaces the current framing, which is a 2×2 box centred on the object's **top-left corner** — an asymmetric footprint covering the bridge tile plus the tiles above, left, and above-left. The new box is symmetric:

```
sprite box: 3 * object.width  x  3 * object.height
centre:     the object tile's centre
```

Both dimensions derive from the object's own size, not a hard-coded 96, so the entity stays correct if tile size ever changes.

Colliders are untouched: the deck stays one tile, the trigger stays one tile on the arrival side. Visual footprint and physical footprint are deliberately different sizes, and only the collider sizes may be reasoned about for gameplay.

The sheet is currently 4 frames of 64×64 (`256×64`), so the 3×3 box stretches it 1.5× and will look soft on pixel art. That is accepted temporarily: the geometry lands now, and the sheet is redrawn at 4 frames of 96×96 (`384×96`) as a separate follow-up. Nothing in the code hard-codes either size.

Overlaying neighbours needs the entity to draw above the tile layers; it already does, because the entity object layer sits after every tile layer in the Tiled layer order. That is a level-authoring constraint worth knowing rather than a code change.

### Sprite orientation

`crossingDirection` no longer reaches the sprite as-is. The entity maps it explicitly:

```
leftToRight -> Sprite{ facing = 'right' }   -- unmirrored: tower left, deck lowers right over the gap
rightToLeft -> Sprite{ facing = 'left'  }   -- mirrored
```

This is the inverse of today's behaviour, which is the bug. The art is unchanged (mirroring is applied to whatever the sheet holds, so it survives the 96×96 redraw). `Sprite`'s `facing` prop keeps its existing meaning (a horizontal mirror flag) and is deliberately not renamed — it is the sprite's own concern, and other entities use it for genuine left/right facing.

### Hold-zone state model

`hasBeenOccupied` is removed entirely, along with `allowEnemies` and the `mayOpen` eligibility predicate. The state machine becomes symmetric and driven by a single per-frame boolean:

```
held = any entity (other than the bridge itself) overlapping
       the trigger tile OR the deck tile

held      and state in (closed, closing)  -> opening
not held  and state in (open, opening)    -> closing
animation finish: opening -> open, closing -> closed
```

Both transitions reverse the animation from the current frame when interrupting an in-flight one, and play from the appropriate end when starting fresh. Deck solidity stays coherent across `opening`/`open`/`closing` and absent only in `closed`, exactly as now.

The lead-in trigger tile being part of the *hold* zone — not a one-shot `enter` event — is what makes `hasBeenOccupied` unnecessary. An entity that has triggered the bridge but not yet reached the deck is still standing in the trigger tile, so it is still holding the bridge down; the "just opened with nobody on it" reversal the flag existed to prevent can no longer happen.

The trigger `Collider` is kept as a sensor purely so the zone still draws under `drawphysics`; state is driven by overlap queries, not by its `enter` callback.

Occupancy queries keep the generous upward height margin so an entity resting on the deck (feet at the tile's top edge, body above) is caught.

### Data files

The template, both sandbox representations, and the fixture are updated together:

- `res/templates/drawbridge.tx` — `facing` becomes `crossingDirection` defaulting to `leftToRight`; `allowEnemies` removed.
- `res/map/sandbox.tmx` — the per-object `facing="left"` override is redundant against the new default and is dropped, leaving the object inheriting the template.
- `res/map/sandbox.lua` — the hand-maintained STI export of the above; kept byte-consistent with the `.tmx` by hand.
- `res/map/drawbridge_fixture.lua` — `crossingDirection = "leftToRight"`, `allowEnemies` removed, comments updated.

## Testing Decisions

A good test here asserts what a player or designer can observe — the bridge's state over time, whether anyone fell, where the deck is solid — not which helper function returned what. The three existing tiers each keep their role:

- **`tests/unit/drawbridge_test.lua`** — pure decision helpers only, still requiring `src.entities.drawbridge.drawbridge_support`. Tests for `mayOpen` are deleted with the predicate. Tests for `triggerOffsetX` move to the new value names. New tests cover the symmetric hold-driven transition table, including the previously-unreachable reopen-then-close path.
- **`tests/integration/drawbridge_test.lua`** — real entity under the LÖVE mock. The two eligibility tests (`an enemy cannot open the bridge by default`, `an enemy can open the bridge once opted in`) are deleted; `once open, an enemy can cross the deck without falling` and `every drawbridge resets to closed on level restart` stay. New: anything (not just a player) entering the trigger opens the bridge.
- **`tests/e2e/drawbridge_test.lua`** — headed, real rendering, the only tier that can catch the sprite orientation and the walk-across-without-falling criteria. The existing `the bridge closes once the last occupant leaves, and a re-trigger mid-close reverses back to open` scenario currently stops asserting the moment it sees `opening` again — that stopping point is exactly where the stuck-down bug lives, so the scenario is extended to walk the player clear a second time and assert the bridge reaches `closed`.

Prior art to follow: `tests/unit/ground_support_test.lua` for the pure-helper style, and the existing e2e drawbridge scenarios for harness/query/capture conventions. Assertions go through `tests/support/queries.lua`, not entity internals.

Naming and location follow this repo's existing Lua convention — `tests/<tier>/<name>_test.lua`, registered in that tier's `run.lua` — not the TypeScript conventions in the generic skill guidance.

## Out of Scope

- Renaming `Sprite`'s `facing` prop or changing how mirroring works for any other entity.
- Vertical, multi-tile, or diagonal bridges.
- Re-introducing entity-type eligibility in any form (the hook is gone, not commented out).
- Backwards compatibility for maps authored with the old `facing` / `allowEnemies` properties.
- Migrating any other entity into the new directory layout — the loader will support it, but only the drawbridge moves now.
- Redrawing `res/img/entity_drawbridge.png` at 96×96 frames — the geometry lands now, the art is a follow-up. Until then the existing 64×64 frames stretch 1.5× and look soft.
- Making any other entity's sprite footprint differ from its collider.
- Any change to how sprites are layered or drawn relative to the tilemap.
- Bridges driven remotely by switches or `target` wiring.

## File Structure

```
src/entities/drawbridge/
  drawbridge.lua
  drawbridge_support.lua
```

## Acceptance Criteria

- [ ] `src/entities/drawbridge_support.lua` and `src/entities/drawbridge.lua` no longer exist at the old paths; both live under `src/entities/drawbridge/` with their names intact.
- [ ] `drawbridge_support.lua` carries a comment explaining why it is a separate file.
- [ ] A Tiled object of type `drawbridge` resolves through `src.entities.?.?` with no stub file and no per-entity loader special-casing.
- [ ] A failed entity resolution prints one error, not one per candidate path.
- [ ] No occurrence of `facing` or `allowEnemies` remains in any drawbridge source, template, map, fixture, test, or doc.
- [ ] `crossingDirection = "leftToRight"` places the trigger one tile left; `rightToLeft` one tile right.
- [ ] A missing or unrecognised `crossingDirection` falls back to `leftToRight` rather than erroring.
- [ ] A `leftToRight` bridge renders unmirrored — tower on the left, deck lowering rightward over the gap tile — verified by e2e capture.
- [ ] The sprite draws 3×3 tiles centred on the object tile, derived from the object's own dimensions rather than a hard-coded pixel size.
- [ ] The deck and trigger colliders remain one tile each; the larger sprite changes nothing a player can stand on or trigger.
- [ ] The sprite visibly overlaps the eight surrounding tiles, drawn above the tilemap.
- [ ] Walking into the trigger lowers the deck before the player reaches the gap; the player crosses without ever being dead or falling.
- [ ] The bridge stays down while any entity overlaps the trigger tile or the deck.
- [ ] The bridge raises once nothing overlaps either zone.
- [ ] Turning back mid-open reverses the animation from the current frame and raises the bridge.
- [ ] Turning back onto a mid-raise bridge reverses it from the current frame and lowers it.
- [ ] **A bridge that has reopened after starting to close still closes again once cleared** — asserted end-to-end, and covered in the unit tier.
- [ ] A push box shoved into the trigger opens the bridge.
- [ ] An enemy standing on an open deck holds it down.
- [ ] Approaching from the wrong side leaves the gap exposed and the player falls in.
- [ ] Every drawbridge resets to closed on level restart.
- [ ] `./test-unit.sh`, `./test-integration.sh` and `./test-e2e.sh` all pass.
- [ ] The sandbox level runs with the drawbridge working, using the template default with no property overrides.

## References

- `docs/adr/0003-multi-file-entity-directories.md` — the entity directory convention and loader change.
- `CONTEXT.md` — the **Drawbridge** and **Reversible timeline** glossary entries.
- `AGENTS.md` — physics gotchas that constrain this entity (`collider.walkable`, colliders flush with the ground surface).
- `.scratch/drawbridge/` — the original drawbridge design, referenced by comments in the current source.
