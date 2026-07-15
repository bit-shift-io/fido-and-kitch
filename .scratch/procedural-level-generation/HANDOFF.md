# Handoff — Procedural Level Generation Tool

## Summary

A standalone offline CLI tool (new `tools/` directory, plain Lua, shell-script launcher) that generates complete, playable-but-bland levels for hand-tweaking in Tiled. Output per level: a `.tmx` (editable source), an auto-exported `.lua` (via the Tiled CLI, so it's immediately playtestable with `love . map=generated/<name>.lua`), and a solution walkthrough. Solvability is **guaranteed by construction** (ADR 0002): the planner builds a solution DAG of objectives first — colored keys → cages → birds with paths → exit door `actor_count` countdown — realises terrain around it with a movement model fed by real `src/` constants, then decorates. Puzzle patterns are pluggable rule modules so future props drop in as new files. Dials: `--seed`, `--count`, `--size`, `--difficulty`, `--coop required|optional`.

## Suggested implementation order

01 → 02 → 03 → 04, then 05 and 08's dressing-half in any order; 06 and 07 (and 08's enemy-half) when their game features have shipped.

- **01 walking-skeleton** first: proves the whole pipe (CLI → TMX → Tiled export → runs in game) with trivial content.
- **02 terrain-and-traversal**: the movement model is the invariant everything else leans on — build and test it early.
- **03 objective-spine**: first genuinely playable output; the walkthrough emission lands here.
- **04 puzzle-rule-library**: converts the planner to composed rules; everything after is "just rules".
- **05 hazards** and **08 dressing/coins** are independent after 03.
- **06 coop-dial**, **07 pushable-rules**, and **08's enemies** are gated on game features (see blockers).

## External blockers (important)

Pushables (push box, boulder), pressure switches, and enemies (spider, robot) are **designed but not yet implemented in the game** — the glossary describes them, `src/` does not contain them. The user confirmed they will land before this tool is built. If implementation starts anyway, issues 01–05 plus 08's dressing-half are unblocked today; verify the features exist before starting 06, 07, or enemy placement.

## Key references

- PRD: `.scratch/procedural-level-generation/PRD.md`
- Decisions/rationale: `.scratch/procedural-level-generation/DECISIONS.md`
- ADR 0002 (`docs/adr/0002-solution-first-level-generation.md`) — solution-first construction + rule library
- ADR 0001 (`docs/adr/0001-pushable-motion-and-snap-model.md`) — constrains issue 07's rules
- Glossary: `CONTEXT.md` (Cage objective, Level generator, Solution-first generation, Puzzle rule, Solution walkthrough)

## Implementer notes & gotchas

- **Entity wiring ground truth** (read these before emitting objects): `src/entities/cage.lua` (unlock via `Usable.requiredItem = key_<color>`; `path` object property; spawns `actor`), `src/entities/exit_door.lua` (`actor_count` Variable counts down; door opens at 0), `src/entities/switch.lua` (`target` object property → `target.entity:switch()`), `src/entities/bird.lua` (polyline path; fires `object:exec('finish')` at path end). Bird actions (flick switch, instant-exit) are authored as `object:exec` Lua snippets in object properties — mirror how `sandbox.tmx`/`ll1.tmx` do it.
- **Tiled CLI**: `tiled --export-map lua in.tmx out.lua`; on this machine it's `/Applications/Tiled.app/Contents/MacOS/Tiled` (v1.12.2, verified). The launcher should search PATH then the app bundle, and degrade to `.tmx`-only with a warning.
- **TMX specifics**: existing maps use base64 tile data, external tilesets by relative path (`../tilesets/generic_platformer_tiles.tsx`), object templates in `res/templates/` (`spawn.tx`, `key.tx`, `cage.tx`, `exit.tx`, `switch.tx`, …). Tiled object Y-origin quirks matter — entities compute centre as `(x + w/2, y - h/2)`, i.e. tile-object convention; copy coordinate conventions from existing maps rather than reasoning from the TMX spec.
- **Constants from `src/`**: the tool must require game source headlessly for tile size / jump / speed constants. `tests/` already runs game logic without LÖVE — follow its patterns; add small seams in `src/` if a constant is tangled in LÖVE-dependent code (seams preserve runtime behaviour, see glossary "Testability seam").
- **Determinism**: no `math.random` global state; self-contained seeded PRNG; batch item i's seed derived from base seed. Golden-file test locks the TMX writer.
- **Map export config**: hand-made `.tmx` files carry an `<editorsettings><export …>` block so Tiled re-exports to the right `.lua` on save — emit that too, so the hand-tweak → re-export loop works.
- **Test harness**: dependency-free headless tests in `tests/` run by `./test.sh` (see `tests/README.md`). No LÖVE window in tests.
- `res/map/generated/` may need a `.gitignore` decision (generated candidates vs. kept levels) — surface it during issue 01 rather than deciding silently.
