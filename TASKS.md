# Template-driven entity data via `.tj` templates (grill 2026-08-29)

Plan from `NOTES.md` (2026-08-29 grill). Target end-state: `.tj` templates in
`res/entities/` are the single source of truth for entity default + sprite data;
entity `.lua` files keep logic only; file-typed template props are converted to
runtime paths at load; runtime-synthesized objects merge the template too.
Order matters: conversion first, then sprite props + lua refactor per entity,
then the rename.

## Phase 1 — Path conversion for file-typed props

- [x] `src/map/tj_template.lua` — rewrite `type == 'file'` property values through
  `stiUtils.format_path(templateDir .. value)` when building the template's typed
  property array (cached, idempotent).
- [x] `src/map/tmj.lua` `parseObject` — same rewrite for instance file props
  (relative to `mapDir`).
- [x] `res/entities/key.tj` — revert `image` prop back to `../img/entity_key.png`
  (native Tiled-relative; uniform with all other editor files).
- [x] Verify: `./test-unit.sh`, `./test-integration.sh`. New unit tests in
  `tests/unit/template_file_props_test.lua` (template-relative and map-relative
  conversion + cache-once).

## Phase 2 — Sprite data into templates (17 files)

- [x] Add flat sprite props to each `res/entities/*.tj`: `image` (file), `frames`
  (int), `duration` (float), `loop`/`playing` (bool), `scale`/`scaleX`/`scaleY`
  (float), `spriteOffsetY` (float), tint where used — mirroring `Sprite{}`'s
  constructor fields. All 17 added (pressure_switch excluded: no sprite, manual
  quad). Also fixed `teleport.tj` image drift (`teleporter_1.png` →
  `entity_teleporter.png`). Pinned by `tests/unit/template_sprite_props_test.lua`.
- [x] Keep behavioral props already present (speed, endBehavior, spawnType,
  maxSpawns, crossingDirection, allowPushWhenStoodOn, target…). Kept + renamed
  `mover_platform.tj` `endBehaviour` → `endBehavior` (typo, code path).
  Asserted by `template_sprite_props_test`.

## Phase 3 — Entity `.lua` refactor

- [x] Add a small shared spec helper that reads merged `object.properties.*`
  (with coercion) and builds `Sprite{}` — no hard-coded `image`/frames in
  templated entities. `src/entities/sprite_props.lua` (`SpriteProps.fromObject`)
  + `tests/unit/sprite_props_test.lua`.
- [x] Strip `DEFAULT_*`/`or` fallbacks now covered by template merge (fixes the
  `mover_platform` speed 50-vs-100 drift). Defaults now 50 / 0.5; defaults test
  updated.
- [x] `EntityFactory:loadEntity` — auto-append `res/entities/<type>.tj` to mock
  objects with no `template` and rerun the merge; probe existence once (cached)
  so `npc_*` without templates skip cleanly. Implemented as
  `_mergeTemplateProps` in `src/map/entity_factory.lua` (module-level
  `templateCache` + `coerceProp`; instance wins).
- [x] Keep tests green per entity. Unit 506, integration 133 (final).

## Phase 4 — Rename + docs

- [x] `res/editor/` → `res/entities/`; update `../entities/` refs in every
  `res/map/*.tmj` (plus tests/fixtures, tests/unit, tests/integration,
  tools/level_generator, docs; zero `editor/` refs remain).
- [x] Update AGENTS.md / ARCHITECTURE.md / CONTEXT.md / README.md /
  tests/README.md (`res/entities/` refs; template-driven sprite data).

## Deferred

- Editor script for `spriteOffsetY` etc. in the Tiled UI.
- NPCs/players untouched (code-side config, no templates).