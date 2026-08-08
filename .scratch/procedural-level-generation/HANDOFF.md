# Handoff — Procedural Level Generation Tool

## Summary

A standalone offline CLI tool (new `tools/` directory, plain Lua, shell-script launcher) that generates complete, playable-but-bland levels for hand-tweaking in Tiled. Output per level: a `.tmx` (editable source, immediately playtestable with `love . map=generated/<name>.tmx` — **the game loads `.tmx` directly** via `src/map/init.lua`'s `Tmx.parse()` + STI, so no Tiled CLI export step is needed) and a solution walkthrough. Solvability is **guaranteed by construction**: the planner places colored keys and matching cages into zones a movement model (fed by real `src/` constants; the player has no jump — see Key references) already guarantees are reachable, then decorates. The exit opens automatically once every cage is used (`all_cages_unlocked`, not a bird/`actor_count` countdown — see Key references). Puzzle patterns are pluggable rule modules so future props drop in as new files. Dials: `--seed`, `--count`, `--size`, `--difficulty`, `--coop required|optional`.

## Suggested implementation order

01 → 02 → 03 → 04, then 05 and 08's dressing-half in any order; 06 and 07 (and 08's enemy-half) when their game features have shipped.

- **01 walking-skeleton** first: proves the whole pipe (CLI → TMX → Tiled export → runs in game) with trivial content.
- **02 terrain-and-traversal**: the movement model is the invariant everything else leans on — build and test it early.
- **03 objective-spine**: first genuinely playable output; the walkthrough emission lands here.
- **04 puzzle-rule-library**: converts the planner to composed rules; everything after is "just rules".
- **05 hazards** and **08 dressing/coins** are independent after 03.
- **06 coop-dial**, **07 pushable-rules**, and **08's enemies** are gated on game features (see blockers).

## External blockers (resolved)

Pushables (push box, boulder), pressure switches, and enemies (spider, robot) were designed-not-shipped when this doc was written. They have since landed in `src/entities/` (`push_box.lua`, `boulder.lua`, `pushable_prop.lua`, `pressure_switch.lua`, `npc_spider.lua`, `npc_robot.lua`). All 8 issues are unblocked as of implementation start (2026-08-08).

## Key references

- PRD: `.scratch/procedural-level-generation/PRD.md`
- Decisions/rationale: `.scratch/procedural-level-generation/DECISIONS.md` — this is the authoritative rationale doc; ADR 0001/0002 referenced below were never actually written, `docs/` doesn't exist in this repo
- Glossary: `CONTEXT.md` (Cage objective, Level generator, Solution-first generation, Puzzle rule, Solution walkthrough)
- Test tooling has moved on from the single `./test.sh` this doc and DECISIONS.md assume — use `./test-unit.sh` (headless logic) and `./test-integration.sh` (map-loading checks) per `tests/README.md`

## Implementer notes & gotchas

- **Entity wiring ground truth** (read these before emitting objects): `src/entities/cage.lua` (unlock via `Usable.requiredItem = key_<color>`; spawns a bird/rabbit `actor` that follows the releasing player — no path, no exec); `src/entities/exit_door.lua` (opens via the `all_cages_unlocked` EventBus event, emitted by `src/states/ingame_state.lua` once every cage's `cage_unlocked` has fired — the `actor_count` `Variable` and `exitInstant`/`exitThroughDoor` are dead code, never called); `src/entities/switch.lua` (`target` object property → `target.entity:switch()`). **Bird polyline paths and `object:exec` firing don't exist in the NPC code** — `sandbox.tmx`'s cage `path` property is authored but read by nothing (DECISIONS.md Q13). Don't author bird paths/exec snippets; a cage only needs `color` (and optionally `spawn_type`).
- **No Tiled CLI export needed**: the game loads `.tmx` directly (`src/map/init.lua` calls `Tmx.parse()` then `sti()` when the path ends in `.tmx`), so the tool only ever needs to emit `.tmx` — no `export.lua`, no Tiled-binary detection, no degrade-without-Tiled path.
- **TMX specifics**: existing maps use base64 tile data, external tilesets by relative path (`../tilesets/generic_platformer_tiles.tsx`), object templates in `res/templates/` (`spawn.tx`, `key.tx`, `cage.tx`, `exit.tx`, `switch.tx`, …). Tiled object Y-origin quirks matter — entities compute centre as `(x + w/2, y - h/2)`, i.e. tile-object convention; copy coordinate conventions from existing maps rather than reasoning from the TMX spec.
- **Constants from `src/`**: the tool must require game source headlessly for tile size / jump / speed constants. `tests/` already runs game logic without LÖVE — follow its patterns; add small seams in `src/` if a constant is tangled in LÖVE-dependent code (seams preserve runtime behaviour, see glossary "Testability seam").
- **Determinism**: no `math.random` global state; self-contained seeded PRNG; batch item i's seed derived from base seed. Golden-file test locks the TMX writer.
- **No re-export loop needed**: since the game loads `.tmx` directly, hand-tweaking a generated map in Tiled and saving is immediately playable — no `<editorsettings><export …>` block or export step required.
- **Test harness**: dependency-free headless tests in `tests/` run by `./test.sh` (see `tests/README.md`). No LÖVE window in tests.
- **Resolved (2026-08-08):** `res/map/generated/*` is gitignored (with `!res/map/generated/.gitkeep`, matching the existing `bin/*` convention) — candidates are disposable by default; a designer who wants to keep one moves/renames it into `res/map/` proper or `git add -f`s it.
