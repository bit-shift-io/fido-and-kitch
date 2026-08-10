# Fido and Kitch — ASCII Map Export Tool: Confirmed Requirements

Grill notes (2026-08-10). Feature: export a map's terrain as ASCII art with a
legend, for pasting into an AI agent (e.g. to generate an image).

## Related code (grounding)

- Run-flag precedent: `e2e=<file>` detours early in `src/main.lua` `love.load`
  (`findE2ETestFile`, `src/main.lua:98-117`) — `export=<map>` mirrors it:
  detect arg, hand off, `return` before the normal `Game()` construction.
- Solid ground: `src/map/init.lua:91` builds static bodies from **any** layer
  (tile layer or objectgroup) whose `properties.collision` is truthy. ll1 uses
  a `ground` tile layer with `collision=true`; sandbox uses a `collision`
  objectgroup (`collision=true`) of rect objects. The exporter must read the
  same signal, not the layer name.
- Killzones: `src/entities/kill_zone.lua` reads `properties.deathType`,
  **defaulting to `'unknown'`**; code supports `water`, `spikes`, `lava`.
  Current maps only use `water` (sandbox.tmx:39, fab1.tmx:42/47). Killzone
  rects live in objectgroups (sandbox `kill` group).
- `src/map/tmx.lua` parses `.tmx` directly; maps are tile grids
  (e.g. ll1 = 36x22, sandbox = 20x20, tile = 32px).
- `README.md` exists in project root — add the export note there.

## Confirmed decisions (asked + answered)

1. **Scope**: terrain only — `#`, water, `[space]`, plus other hazard
   symbols. All gameplay objects (ladders, keys, doors, cages, coins, spawn,
   drawbridges, NPCs…) are **excluded**; they're authored in the editor.
2. **Run flag**: `love . export=sandbox` (compact form of `map=`).
3. **Behavior**: print the export to stdout, write the file, then **exit**
   without a window.
4. **Output content**: full header + grid + legend.
   - Header: map name, width/height in tiles, tile width/height in px
     (e.g. `Export of sandbox (20x20, tile 32px)`).
   - Grid: one character per tile.
   - Legend: the symbol table printed near the grid.
5. **File dump**: write `export_<map>.txt` into the LÖVE **save dir** via
   `love.filesystem.write` (user confirmed save dir is fine; do NOT use plain
   `io.open` — that's a different (project-root cwd) location and a fragile
   dependency on launch cwd).
6. **Legend symbols**:
   - `#` solid ground
   - `w` water
   - `f` fire
   - `l` lava
   - `s` spikes
   - `.` nothing
   - Killzone `deathType` maps to its symbol; **unknown/unset deathType
     defaults to `w` (water)**.
7. **Solid source**: layers (tile or objectgroup) with `collision=true`.
8. **Hazard source**: `kill_zone` objects only; a cell covered by a killzone
   rect renders as its deathType symbol (not `#`).

## Open / deferred

- Edge case: overlapping killzone rects with different deathTypes — last-wins
  ordering is fine for now.
- Non-water hazard maps don't exist yet; symbols (`f`/`l`/`s`) are for future
  maps only.

## Who reads this

Implement as a headless detour in `src/main.lua` (or a `src/export_ascii.lua`
module) keyed off the `export=` flag, reusing `src/map/tmx.lua` / the Map load
path to rasterize cells without constructing a full `Game`. Add the run-flag
note to `README.md`. Verify by running `love . export=<map>` and checking the
file in the save dir.
