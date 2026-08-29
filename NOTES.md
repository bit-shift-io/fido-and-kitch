# Template-driven entity data via `.tj` templates (2026-08-29)

Grill notes. Scope: entity defaults + sprite/art metadata move out of `.lua` into
`res/entities/*.tj` templates; templates become the single source of truth; the
runtime reads merged `object.properties`. `TASKS.md` holds the phased plan.

> Supersedes the completed TMX→TMJ migration notes (all tasks `[x]` before).

## Confirmed model (asked + answered)

1. **Target duplication = Lua vs template defaults** — the `.tj` becomes the
   single source of truth for an entity's default properties; strip matching
   `or DEFAULT` fallbacks from `.lua` where a template exists. Already drifted:
   `mover_platform.tj` `speed: 50` vs `mover_platform.lua` `or 100`.
2. **Most sprite data moves into templates** — the editor is visual. Sprite
   fields (image, frames, duration, loop, playing, scale, spriteOffsetY, tint…)
   become flat template props merged like any other property. `parseProperties`
   (`tmj.lua:312`) already coerces `file→string`, `int/float→number`,
   `color→hex string`. Entity `.lua` keeps logic (FSM, geometry from object
   w/h), not baked art strings. A future editor script is planned to surface
   props like `spriteOffsetY` in the Tiled UI.
3. **Layout + paths** — `res/editor/` → `res/entities/` (flat rename). The
   `.tiled-project` was moved to `res/` (done). Templates keep native
   Tiled-relative `../img/...` paths (uniform, editor re-save safe); runtime
   needs conversion. The experiment of storing `res/img/...` verbatim in the
   JSON was rejected after further tests — the loader must convert file-typed
   props instead.
4. **`loadEntity` merges the template** — runtime-synthesized objects
   (replicator→push_box, cage→NPC, IPC spawn) get a `template` path auto-appended
   when the object has none (probe existence of `res/entities/<type>.tj` once,
   cached; `npc_*` have no template and skip). Reuses the `tmj.lua` merge.
   NPCs/players stay code-side (no `.tj` exists for them).

## Conversion precedent

`stiUtils.format_path` (`lib/sti/utils.lua:5`) collapses `dir/../img/x.png` →
`res/img/x.png`. `tj_tileset.lua:82,130` already runs every tileset image through
`tsDir .. path` + `format_path`. Only object `image` (file-typed) props pass
through raw — that is the gap. Fix mirrors the existing pattern:

- `tj_template.lua` — rewrite `type == 'file'` prop values via
  `format_path(templateDir .. value)` (template-relative, cached, idempotent).
- `tmj.lua` `parseObject` — same rewrite for instance file props (mapDir-relative).

## Tileset as the art source (image prop removed)

Templates no longer carry an `image` property; the sprite image is resolved from
the template's **inline tileset tile** — what the Tiled editor previews — and
injected into the merged `object.properties.image` at load:

- `tj_template.lua` `parseTj` — exposes `tilesetImage` (tile 1's image, or the
  tileset image, run through `format_path(templateDir .. value)`) in the parsed
  template table (nil for external-tileset templates).
- `tmj.lua` `parseObject` — `templateTilesetImage` is hoisted out of the
  `if obj.template then` block (its `template` local is block-scoped) and,
  after the instance-props merge, sets `object.properties.image` when absent.
- `entity_factory.lua` `_mergeTemplateProps` — same fallback for template-less
  runtime-mock objects.
- Tilesets were aligned to runtime reality while at it: `boulder.tj` now
  previews `pushable_stone_block.png` (250x250, was `default.png` 32x32),
  `replicator.tj` previews `default.png` 32x32 (was the 768x128 jump_pad sheet).

## Art-size authoring (blocker model extended, grilling NOV pass)

Templates are now authored at the **art size**, following the blocker precedent:
the object box IS the visual footprint, the sprite draws 1:1 centred, and the
colliders are independent of the visuals where that matters.

- `cage.tj` / `teleport.tj` / `exit_door.tj` objects went 32x32 → 64x64; their
  lua dropped the `object.width * 2` + `height * 0.5` lift entirely (the art was
  always ~square/1:1, so 2x only looked right against a 32 template). Their use
  sensors are object-derived, so they follow the art footprint (bottom-flush).
- `drawbridge.tj` also went 32x32 → 64x64 (art box), but the deck/trigger/
  occupancy colliders MUST stay one tile, so the gameplay footprint is driven by
  new template props `colliderWidth`/`colliderHeight` (32 each), anchored at the
  object's own corner and falling back to the object size when absent — the
  "collision independent of the visual" case, expressed as extra properties.

## Sprite offsets

`spriteOffsetX`/`spriteOffsetY` (px, positive = right/down) are the general
authorable knobs for sprite art, applied to `sprite.position` only — colliders
never move with them (blocker's original pattern). `cage.lua`/`teleport.lua`/
`exit_door.lua` read Y (`tonumber(object.properties.spriteOffsetY) or 0`);
`drawbridge.lua` reads both X and Y. Written into a template only where the art
needs it (blocker.tj: -6; drawbridge.tj authors a 64x64 art box with
`spriteOffsetY=-64` so the art hangs flush off its bottom edge).

`colliderOffsetX`/`colliderOffsetY` (px, positive = right/down) are the
mirror knobs for the gameplay footprint: `drawbridge.lua` shifts the
colliderWidth/Height rect origin (so deck, trigger, and occupancy all move
together) without touching the art. This is the "collision independent of the
visual" case expressed as offsets, symmetric to the sprite offsets — art knobs
never move colliders and vice versa, so the two never double-apply.

## Editor-first drawbridge (offsets authored in the template, not runtime fixes)

`drawbridge.tj` is authored editor-first: the 64x64 art box is placed in Tiled
with its bottom edge on the floor (exactly the editor preview: bottom-anchored
gid tile, sprite at art-box centre + `spriteOffsetY=-64`), and the one-tile
deck/trigger/occupancy footprint is derived from `colliderWidth`/`colliderHeight`
(32) + `colliderOffsetX`/`colliderOffsetY` (+32/-32 → the art box's bottom-right
quadrant, i.e. the deck under the art's deck part). Existing template-referenced
instances in `res/map/*` inherit these defaults via `_mergeTemplateProps`; the
test fixture `tests/fixtures/drawbridge_room.tmj` carries explicit offset props
(shielded from template drift): its object sits at (96,160) so the deck lands
exactly over the physical gap at (128,128,32,32).

## Deferred

- Editor script for `spriteOffsetY` etc. in the Tiled UI.
- NPCs/players untouched (code-side config, no templates).