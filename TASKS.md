# Remove old Lua map system + old TMX/XML systems

Plan from `NOTES.md` (grill 2026-08-28). Target end-state: only `.tmj`/`.tj`/`.tsj`
JSON survives for map/template/tileset loading. All decisions recorded in `NOTES.md`.
Ordered bottom-up (delete leaves before dependents; port tooling before removing loaders).

## Phase A — Port tooling to JSON

- [x] `src/export_png.lua` — port from `.tmx` to JSON: use `src/map/tmj.lua`, drop `require('src.map.tmx')`; update `resolveMapFile` to only consider `.tmj`/`.lua`→`.tmj`. Keep `tests/unit/export_png_test.lua` (pure functions).
- [x] `tools/level_generator/tmx_writer.lua` — XML writer; remove it and its unit test `tests/unit/level_generator_tmx_writer_test.lua` (main.lua already writes `.tmj` via `tmj_writer.lua`); drop `tmx_writer_test` entry from `tests/unit/run.lua`.
- [x] Rewrite `tools/README.md` generation note: `<seed>.tmx` → `<seed>.tmj`.

### Phase A follow-ups (cleanup, done with A)
- [x] Rename legacy `result.xml` field → `result.tmj` in `tools/level_generator/main.lua` (used at main.lua:638,662-669,747; field is actually tmj content). Update `tests/unit/level_generator_main_test.lua` refs (`a[1].xml`→`.tmj`, `.tmx`→`.tmj` describe) and fix its stale `name="ladder"` XML-attribute assertion (line 92) to parse the tmj JSON and check for a ladder objectgroup layer. This was pre-existing failing #4 above.

## Phase B — Strip + rename shared dual-format modules

- [x] Rename `src/map/tmx_template.lua` → `src/map/tj_template.lua`; strip XML branch (`parseTx` via `tmx_xml`); keep JSON `parseTj`. Update require in `src/map/tmj.lua` (only remaining consumer).
- [x] Rename `src/map/external_tileset.lua` → `src/map/tj_tileset.lua` (JSON-only name); strip XML branch (`resolveShapeUncached`/`.tsx` via xml2lua); keep `resolveTsjUncached`. Update require in `src/map/tmj.lua` (+ `lib/sti/init.lua:23`).
- [x] Trim XML branches from `tests/unit/external_tileset_test.lua` (JSON-only now; fixed the pre-existing `../img/`→`res/img/` failures plus a stale width assertion; consolidated uncropped/cropped into one per-tile image-collection case). `tests/unit` is green again (495 passed, 0 failed).
- [x] Delete `tests/unit/tmx_template_test.lua` (XML-only) and `tests/unit/tmx_test.lua` (XML-only); remove both entries from `tests/unit/run.lua`.

### Phase B follow-ups (reorder note)
- [x] Deleting `tmx_template.lua` broke `src/ui/map_list.lua` (requires `src.map.tmx` → deleted module). Ran the Phase E UI cleanup early to restore loading: stripped `.lua`/`.tmx` branches from `src/ui/map_list.lua` (JSON-only), removed unused `require('src.map.tmx')` from `src/ui/map_card.lua`, updated `tests/unit/map_list_selection_test.lua` fake filenames `.tmx`→`.tmj`.

## Phase C — Delete XML core + helpers

- [x] Delete `src/map/tmx.lua` and `src/map/tmx_xml.lua`.
- [x] Delete `lib/xml2lua` (confirmed: only used by `src/map/external_tileset.lua` + `src/map/tmx_xml.lua`; both are stripped/removed in Phases B–C, so `grep xml2lua` will be clean).
- [x] Delete migration tools `tools/tx_to_tj.py`, `tools/convert_to_templates.lua`, and `tools/convert_to_templates.py`.
- [x] Remove `xml2lua` from `setup.sh` (delete the clone block + `git apply patches/xml2lua.patch` line) and delete `patches/xml2lua.patch`. All other libs are used and stay (STI=render, hump/tween/Slab/bump/dkjson all referenced).
- [x] Delete `tests/fixtures/tmx/tmx_room.tmx` and `tests/fixtures/tmx/tmx_room.tsx` (and any XML fixtures dir). Also deleted `tests/integration/tmx_test.lua` (XML-only tests of removed `.tmx` loading) + its `run.lua` entry.

## Phase D — Loader dispatch cleanup (`src/map/init.lua`)

- [x] `src/map/init.lua` `loadSti`: remove `.tmx` branch and `.lua` fallback; keep only JSON (always `sti(Tmj.parse(path))`). Drop `require('src.map.tmx')`.
- [x] `src/map/init.lua` `resolveMapFile`: remove `.tmx`/`.lua` branches; always return `path + '.tmj'`.
- [x] Audit `lib/sti/init.lua` loader entry points: remove `.lua` (line ~47 `ext == ".lua"`) and any `.tmx` handling; retain the table-input + tile-render path (drawLayer/drawTileLayer/sprite batches) used by `parallax_renderer.lua`. Verify game still runs a `.tmj` map.

## Phase E — UI cleanup

- [x] `src/ui/map_list.lua` — strip `.lua`/`.tmx` format branches; only list `.tmj` maps. (Done early, see Phase B follow-ups.)
- [x] `src/ui/map_card.lua` — strip `.lua`/`.tmx` branches; remove `require('src.map.tmx')`; use JSON thumbnail path. Update `tests/unit/map_card_test.lua` / `map_list_selection_test.lua` if they reference old formats. (Done early, see Phase B follow-ups.)

## Phase F — Test fixture triage + conversion

- [x] Triage `tests/fixtures/*.lua` (~35 Gen-1 maps): `grep` tests/run.lua files to find which fixtures are actually required; list keep-vs-delete.
- [x] Convert each kept `.lua` fixture to a `.tmj` (script/port the STI-shaped Lua table into TMJ JSON, incl. external-`.tsj` tilesets). Keep fixtures only where the tests exercise real stack loading; otherwise rewrite the test to use a `res/map/*.tmj` or a JSON fixture.
- [x] Delete the triaged-out `.lua` fixtures.
- [x] Update fixture-requiring test call sites to the `.tmj` paths.

## Phase G — Fix broken test refs

- [x] Fix 5 call sites passing `res/map/sandbox.tmx` → `.tmj`: `tests/integration/level_layer_render_test.lua`, `tests/integration/blocker_test.lua`, `tests/e2e/diorama_test.lua`, `tests/e2e/npc_visual_test.lua`, `tests/e2e/blocker_test.lua`. Audit for any other stale `.tmx`/`.lua` map refs in tests. (Also fixed `src/states/game_over_state.lua`, `src/ipc/handlers/entity.lua`, `src/ui/map_info.lua`, `tests/e2e/all_maps_screenshot_test.lua`, `tests/integration/all_maps_load_test.lua`, and swept `.tx`/`.tsx` stale comment refs in src/tests/tools. See notes.)

## Phase H — Docs

- [x] `AGENTS.md` — replace `tmx.lua`→`tmj.lua`, `res/map/*.tmx`→`.tmj`, `*.tx`/`*.tsx`→`.tj`/`.tsj` in Layout/map section.
- [x] `ARCHITECTURE.md` — update `.tmx` refs; keep/restate "exported .lua maps are legacy".
- [x] `CONTEXT.md` — fix "Tiled map source: `.tmx` is sole source of truth" → JSON.
- [x] `README.md` — "Save the map as tmx" → `.tmj`.
- [x] `tests/README.md` — `sandbox.tmx` example → `sandbox.tmj`; strip `.lua`/`.tmx` fixture notes.
- [x] Remove any stale `.scratch/*DECISIONS.md` code-comment references encountered (log as a sweep task). (Generic historical `DECISIONS.md` citations left as-is — documented "no longer in-repo"; made format-specific comment fixes in `src/map/tj_tileset.lua` + `tests/integration/tmj_template_resolve_test.lua`. Also swept `.vscode/launch.json`.)
- [x] Run `./test-unit.sh`, `./test-integration.sh`, `./test-e2e.sh` (CI skip allowed) to verify removal is clean. (`./test-unit.sh` = 495 passed/0 failed; `./test-integration.sh` = 133 passed/0 failed. E2E has pre-existing failures unrelated to format removal — tests referencing maps deleted in the earlier refactor + GPU-dependent rendering.)
