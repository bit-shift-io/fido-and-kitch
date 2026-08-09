# Fido and Kitch — Ladder Props Feature: Confirmed Requirements

Grill notes (2026-08-09). Feature: author ladders as per-rung gid "props" in
Tiled so they render in the editor, keep identical in-game behavior, and
support real switch on/off.

## Related code (grounding)

- `res/templates/ladder.tx` — template; object `type="ladder"` with `gid`,
  width/height 32. Rendering art comes from props.tsx tile id 2
  (`../img/ladder.png`, 128x32, 4 frames).
- `res/map/*.tmx` — ladders are authored as per-rung template tile objects
  (`<object template="../templates/ladder.tx" x= y=/>`, no type/width/height),
  one 32px rung per step, bottom-anchored (object `y` = rung bottom edge).
  Loaded via `Tmx.parse` (`src/map/tmx.lua`) then STI.
- `src/map/ladder_merger.lua` — pure: groups same-column rungs by vertical
  contiguity into one logical `{rect, rungs, properties}`; differing custom
  properties force a vertical split.
- `src/map/entity_factory.lua` `annotateLadders` — marks each rung with a
  shared `ladderFamily` rect + `leadRung` flag (lowest rung is lead).
- `src/entities/ladder.lua` — lead rung builds one merged sensor collider from
  the family rect + tiled `ladder.png` sprites; upper rungs are thin aliases
  forwarding to the lead. `:tileHeight()`, `:resizeTileHeight(n,'top'|'bottom')`
  (moves only the named edge), `:grow(n)`; `Ladder:switch` hides on `'off'`
  (removes collider + sprites) and restores on `'on'` (keeping grown size).
- Switch `target` resolves a single object id (`switch.lua`, `teleport.lua`
  pattern); `map:getObjectById(id).entity` / `object:exec` script plumbing in
  `src/map/entity_factory.lua`. Any rung id works as a switch target.
- `tools/level_generator/main.lua` emits per-rung `template="../../templates/ladder.tx"`
  objects from `buildTerrain` (bottom-anchored, one per 32px tile).
- **gid tile objects are bottom-anchored; gid-less rectangles top-anchored.**
  All ladder geometry is now bottom-anchored.

## Confirmed decisions (asked + answered)

1. **Prop form**: "One tile object per rung" — each 32px rung is its own
   gid'd tile object (`type=ladder`, gid from props.tsx, 32x32), stamped via
   the existing `res/templates/ladder.tx`, stacked N-high.
2. **Rung grouping**: "auto merge by column + contiguity + matching custom
   properties." Engine merges same-column, vertically-adjacent rungs into one
   ladder when their custom-property sets match — a rung tagged with a
   differing custom property can force a vertical split. Any rung's object id
   works as a switch target because all fold into one entity.
3. **Toggle off**: "Add real off" — switch `off` hides the ladder and removes
   its climb sensor; switch `on` restores it (keeping grown size). Just extend
   `Ladder:switch` to also handle `off`.
4. **Player mid-climb**: climbing player "Falls safely" when the ladder hides
   (same as letting go of climb mid-air).
5. **Deliverable**: "Full feature + migrate existing maps" — engine changes,
   per-rung rung-merging, hide-on-off, AND migrate `res/map/*.tmx` + test
   fixtures + `tools/level_generator` output to the per-rung gid format, with
   tests.
6. **Anchor semantics (amendment from grill)**: "you can change the behaviour
   to match the prop if that's better long term, from top to bottom." Adopt
   **bottom-anchored** ladder geometry everywhere, matching Tiled gid props
   (object `y` = ladder's bottom edge, top = `y - height`). Do NOT preserve
   top-anchored legacy semantics; merged logical rect, sprite placement,
   collider, and `resizeTileHeight`/`grow` math are all recomputed against
   bottom-anchored y. Grow upward keeps the bottom fixed (top rises) — same
   gameplay result as today, cleaner data model going forward.

## Open / deferred

- **Migration execution**: DONE — all maps (`ll1`, `ll2`, `sandbox`, `fab1`,
  `lurid_2p_01`) + all hand-authored fixtures + `tools/level_generator` now use
  per-rung bottom-anchored template rungs. No legacy one-rect ladder objects
  remain.
- Backwards-compatible parsing of one-rect tall ladder objects — NOT built;
  the per-rung model is authoritative (old ladder rects need no legacy support).

## Risks / gotchas for implementation

- **Anchor flip is now the model**: converting rect objects → gid tile
  objects changes top-anchor to bottom-anchor (`tests/unit/map_card.lua:5`,
  `tools/level_generator/main.lua:67`). Per decision 6 this is now the
  intended bottom-anchored behavior, not a bug to work around: merged ladder
  bounds must be recomputed from the rung union (top = min rung `y` minus its
  height), not trusted from any single object's y alone.
- `ll2.tmx` had a ladder (id 19) with `height=19` not a multiple of 32
  (offsets only); during migration it was snapped to the 32px grid.
- `Ladder:resizeTileHeight` + `grow(5)` move the top edge only (bottom stays
  fixed) against the merged/owned family rect; restored state persists grown
  height across the off/on cycle (the logical rect is kept, only sprites +
  sensor hide).
- The legacy layer-level `properties.ladder` sensor-volume path
  (`createLadderVolumes`) has been REMOVED — ladders are entity-only, built
  from per-rung objects via `ladder_merger`.

## Who reads this

Target implementation against `src/entities/ladder.lua`, Tiled `.tmx` objects
in `res/map/*.tmx`, and `tools/level_generator`; verify formats stay in sync
with `res/templates/ladder.tx`; run `./test-unit.sh` + `./test-integration.sh`.