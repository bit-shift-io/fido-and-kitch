# Remove old Lua map system + old TMX/XML systems (2026-08-28)

> **STATUS: COMPLETED.** All tasks in phase A–H (see `TASKS.md`) are done as of
> the TMX→TMJ migration (verified: `.tmx`/`.tx`/`.tsx`/`.lua` map paths removed;
> only `.tmj`/`.tj`/`.tsj` JSON survives). Kept here as a historical record of
> the migration plan.

Grill notes. Scope: kill every non-JSON map path. Target end-state: only
`.tmj`/`.tj`/`.tsj` JSON survives for map/template/tileset loading.

## Confirmed model (asked + answered)

1. **Kill ALL non-JSON paths** — Gen 1 `.lua` maps (STI loader) AND Gen 2
   `.tmx`/`.tx`/`.tsx` XML. Only TMJ/JSON survives.
2. **Test fixtures: triage** — `tests/fixtures/*.lua` (~35 Gen-1 maps):
   keep only what's consumed by tests, convert those to `.tmj`, delete the
   rest.
3. **Migration tools + xml2lua: delete all** — `tools/tx_to_tj.py`,
   `tools/convert_to_templates.lua`, `lib/xml2lua`. (Delete all.)
4. **Rename dual-format modules** — `tmx_template.lua` →
   `tj_template.lua`, `external_tileset.lua` → JSON-only name. Strip XML
   branches internally.
5. **STI: KEEP for rendering** (confirmed active): `parallax_renderer.lua:117`
   calls `map:drawLayer` → STI `drawTileLayer`; object-layer sprite batches
   are STI-built. Full removal would require reimplementing tile rendering.
   Delete only the `.lua`/`.tmx` loader entry points; render path stays.
6. **export_png.lua + tools/level_generator/tmx_writer.lua: port to JSON
   first**, then delete the XML paths. (Not just delete.)
7. **Docs: update all in-scope** — AGENTS.md, ARCHITECTURE.md, CONTEXT.md,
   README.md, tests/README.md, tools/README.md (`.tmx`/`.tx`/`.tsx` refs).
8. **Fix all broken test refs** — ~5 files still reference `sandbox.tmx`
   (level_layer_render_test, blocker_test, diorama_test, npc_visual_test).
9. **UI: strip old formats** — `map_list.lua`/`map_card.lua` only need
   `.tmj`; remove `.lua`/`.tmx` branches + `map_card.lua`'s `src.map.tmx`
   require.

## Files in play (map system, 11 files)

- `src/map/init.lua` — loader dispatch; kill `.tmx`/`.lua` branches of
  `loadSti`/`resolveMapFile` (keep `.tmj`)
- `src/map/tmx.lua` — XML map parser → DELETE
- `src/map/tmx_xml.lua` — XML DOM helper (plus its `lib.xml2lua`) → DELETE
- `src/map/tmj.lua` — JSON map parser → KEEP
- `src/map/tmx_template.lua` — dual-format; strip XML, rename → tj_template.lua
- `src/map/external_tileset.lua` — dual-format; strip XML, rename → JSON-only
- `src/map/{entity_factory,ladder_merger,collision_builder,parallax_renderer,map_parallax}.lua` — format-agnostic → KEEP

## Knock-on fixes

- `src/export_png.lua` (TMX-only + `require src.map.tmx`) → port JSON
- `src/ui/map_list.lua`, `src/ui/map_card.lua` (3-format branches) → strip
- `tools/level_generator/tmx_writer.lua` (XML writer) → port/remove
- `lib/sti/init.lua` STI `.lua`/`.tmx` loader entry points → remove
- `tests/fixtures/tmx/tmx_room.tmx/.tsx` → remove (XML-only test fixture)
- XML-path unit tests (`tmx_test.lua`, `tmx_template_test.lua`,
  `external_tileset_test.lua`, `level_generator_tmx_writer_test.lua`) → update/remove
- 5 call sites pass `sandbox.tmx` (now `.tmj`)
- Remove stale `.scratch/DECISIONS.md` code-comment references if encounterable

## Known stale docs (update in task)

AGENTS.md (`tmx.lua`, `res/map/*.tmx`, `*.tx`/`*.tsx`), ARCHITECTURE.md
(`.tmx`), CONTEXT.md (`.tmx` sole source of truth), README.md ("Save map as
tmx"), tools/README.md (`<seed>.tmx` → `.tmj`), tests/README.md
(`sandbox.tmx` example).
