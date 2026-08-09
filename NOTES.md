# Fido and Kitch — Ladder Props Feature: Confirmed Requirements

Grill notes (2026-08-09). Feature: author ladders as per-rung gid "props" in
Tiled so they render in the editor, keep identical in-game behavior, and
support real switch on/off.

## Related code (grounding)

- `res/templates/ladder.tx` — existing template; object `type="ladder"` with
  `gid`, width/height 32. Rendering art comes from props.tsx tile id 2
  (`../img/ladder.png`, 128x32, 4 frames).
- `res/map/*.tmx` — ladders are authored as plain tall rectangles
  (`type="ladder"`, no gid), one per ladder; loaded via `Tmx.parse`
  (`src/map/init.lua:12-17`) since only `.tmx` exist under `res/map/`.
- `src/entities/ladder.lua` — entity builds one sensor collider from the
  object rect + tiled `ladder.png` sprites; `:tileHeight()`,
  `:resizeTileHeight(n,'top')` (grows up), `:grow(n)`; `Ladder:switch`
  currently only reacts to `switch.state=='on'` via `object:exec('switchOn')`.
- Switch `target` resolves a single object id (`switch.lua`, `teleport.lua`
  pattern); `map:getObjectById(id).entity` / `object:exec` script plumbing in
  `src/map/entity_factory.lua:55-71`.
- `tools/level_generator/main.lua` emits gid-less ladder objects
  (`buildTerrain`, lines ~263-276, ~318, ~341).
- `tests/unit/map_card.lua_test` + `tools/level_generator/main.lua:67` note:
  **gid tile objects are bottom-anchored; gid-less rectangles top-anchored.**

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

- **Migration execution**: migrate-all default — all maps + fixtures +
  generator — but which specific .tmx (ll1, ll2, sandbox, fab1, lurid_2p_01)
  and whether hand-authored fixtures (`tests/fixtures/ladder_platform_room.lua`
  etc.) get converted is a decision for the implementer. Keep legacy rect
  parsing working for .tmx compat if cheap.
- Backwards-compatible parsing of one-rect tall ladder objects (useful during
  transition; not yet a hard requirement).

## Risks / gotchas for implementation

- **Anchor flip is now the model**: converting rect objects → gid tile
  objects changes top-anchor to bottom-anchor (`tests/unit/map_card.lua:5`,
  `tools/level_generator/main.lua:67`). Per decision 6 this is now the
  intended bottom-anchored behavior, not a bug to work around: merged ladder
  bounds must be recomputed from the rung union (top = min rung `y` minus its
  height), not trusted from any single object's y alone.
- `ll2.tmx` has a ladder (id 19) with `height=19` not a multiple of 32
  (offsets only); per-rung conversion must store/round cleanly.
- `Ladder:resizeTileHeight(..,'top')` + `grow(5)` moves `rect.y` up — must
work against merged/owned rung rects, and restored state must persist grown
   height across the off/on cycle (option: keep the logical rect, only hide
   the sprites + sensor).
- Layer-level `properties.ladder` sensor-volume path
  (`createLadderVolumes`, `src/map/init.lua:94`) also exists — check which
  maps use it vs entity path before removing/keeping.

## Who reads this

Target implementation against `src/entities/ladder.lua`, Tiled `.tmx` objects
in `res/map/*.tmx`, and `tools/level_generator`; verify formats stay in sync
with `res/templates/ladder.tx`; run `./test-unit.sh` + `./test-integration.sh`.