# Procedural Level Generation Tool

## Problem Statement

Every level in Fido and Kitch is hand-authored in Tiled — terrain, ladders, keys, cages, bird paths, switches, hazards, dressing — and each one takes significant design time. The team wants more levels than they can hand-build, but doesn't want to give up hand-crafted quality: the bottleneck is producing a *credible starting point*, not the final polish pass.

## Solution

A standalone, offline level generator (not part of the shipped game) that emits complete, playable-but-bland levels as Tiled `.tmx` files plus auto-exported `.lua` maps, along with a human-readable solution walkthrough for each level. Designers run a seeded CLI, playtest candidates immediately, open the keepers in Tiled to hand-tweak, and ship them through the existing export pipeline. Every generated level is solvable **by construction**: the generator builds the solution path first and decorates around it, so no design time is wasted discovering broken levels.

## User Stories

1. As a level designer, I want to run a single CLI command and get a playable level, so that I can start from 80% done instead of a blank map.
2. As a level designer, I want the same seed to always produce the same level, so that I can regenerate a level I liked after changing generator code or flags.
3. As a level designer, I want a `--count N` batch mode, so that I can skim many candidates and keep only the good ones.
4. As a level designer, I want the tool to auto-export the `.lua` map, so that I can playtest a candidate immediately (`love . map=...`) without opening Tiled first.
5. As a level designer, I want a step-by-step solution walkthrough emitted with each level, so that I can verify completability quickly during playtesting.
6. As a level designer, I want generated levels to open cleanly in Tiled with the project's tilesets and templates, so that hand-tweaking feels the same as editing a hand-made map.
7. As a level designer, I want `--size` and `--difficulty` dials, so that I can target bite-sized easy levels or larger complex ones.
8. As a level designer, I want a `--coop required|optional` flag, so that some levels demand genuine two-player teamwork while others are soloable.
9. As a player of a generated level, I want the standard objective structure — find colored keys, unlock all cages, the last cage opens the exit door, both players exit — so that generated levels play like hand-made ones.
10. As a player of a generated level, I want every key, cage, switch, and the exit to be reachable with the game's actual movement (jump reach, ladders), so that the level is completable without glitches.
11. As a player of a co-op-required level, I want puzzles where one player must be positioned to help the other (e.g. holding a momentary pressure switch while the partner passes a door), so that co-op levels feel cooperative rather than parallel-solo.
12. As a player, I want hazards (kill zones such as water/pits) placed so that a careful route through the level never forces a death, so that difficulty comes from challenge, not unfairness.
13. As a gameplay programmer adding a new prop, I want to add one new puzzle-rule module to the generator without touching its core, so that the generator grows with the game.
14. As a level designer, I want released birds to sometimes perform useful actions on their path (e.g. flick a remote switch) before exiting, so that generated levels use the game's full objective vocabulary.
15. As a level designer, I want enemies placed at difficulty-appropriate density in positions that harass but never make the level unwinnable, so that generated levels have pressure without brokenness.
16. As a level designer, I want basic background dressing (gradient, cloud spawner, props) included, so that a generated level doesn't look naked before the polish pass.
17. As a level designer, I want coins sprinkled along and slightly off the solution path, so that levels reward exploration without hand-placement.
18. As a level designer, I want the generator to fail loudly (with a clear message and non-zero exit) if it cannot construct a valid level for the given parameters, rather than emitting a broken map.

## Implementation Decisions

- **Standalone tool** in a new `tools/` directory, plain Lua (LuaJIT-compatible), launched by a shell script. Never required by the game at runtime.
- **Reads gameplay constants from `src/`** (tile size, player jump/walk parameters, pushable rules) rather than duplicating numbers that would drift. Where a constant is not cleanly requirable, extract a testability seam in `src/` rather than copying the value.
- **Solution-first construction** (see ADR 0002): the generator first builds an abstract solution plan — an ordered dependency graph of objectives (key → cage → bird action → … → exit) placed into connected zones — then realises terrain, then decorates. Solvability is never checked after the fact; it is implied by construction.
- **Movement model**: a conservative reachability model derived from real player physics constants (max jump height/distance, ladder rules). The generator only asserts traversals the model guarantees.
- **Modular puzzle-rule library**: each puzzle pattern (e.g. "lever switch opens remote door", "momentary pressure switch + separated door", "push box into hole to bridge a gap", "bird flicks switch on exit path") is a self-contained rule module with a uniform interface: what it requires, what it unlocks, how it expands into entities/terrain, and the walkthrough steps it contributes. New props → new rule files, no core changes.
- **Co-op dial**: players are mechanically interchangeable; `coop=required` is achieved by *spatial separation* of interdependent elements (rules that place a helper station and a beneficiary passage far apart, with a two-agent solution plan). `coop=optional` restricts construction to single-agent-solvable plans.
- **Objective spine**: colored keys unlock matching cages; each cage releases a bird with a generated polyline path; the exit door's `actor_count` equals the number of birds; birds decrement it on exit (last cage therefore opens the door); all players exiting ends the level. Bird path-end actions are emitted as the same `object:exec` event snippets hand-made maps use.
- **Output**: `.tmx` referencing the project's existing tilesets/templates by relative path, plus a `.lua` auto-exported via the Tiled CLI (`tiled --export-map lua`), plus a solution walkthrough text file, all written to a generated-maps directory under `res/map/`. The launcher locates Tiled.app on macOS or `tiled` on PATH; if absent, it emits `.tmx` only and prints a clear warning.
- **CLI contract**: seeded one-shot: `--seed N` (default: random, always printed), `--count N`, `--size small|medium|large`, `--difficulty 1..5`, `--coop required|optional`. Same seed + same flags + same generator version ⇒ identical output.
- **Deterministic RNG**: a self-contained seeded PRNG (not `math.random` global state) so batch items are independently reproducible (item i derives its seed from the base seed).
- **Failure mode**: if constraints can't be satisfied (e.g. tiny map + max difficulty + coop required), retry internally a bounded number of times, then fail with a message; never emit an unsolvable map.

## Testing Decisions

- Tests are fast headless Lua tests in the project's existing dependency-free `tests/` harness (run via `./test.sh`) — matching this repo's convention rather than the TS naming scheme.
- Test **external behaviour of generation stages**, not internals: given a seed and flags, the solution plan is a valid DAG ending at the exit; every objective zone is reachable under the movement model; the emitted TMX parses and references only valid tile GIDs/templates; the walkthrough steps match the plan; same seed ⇒ byte-identical output.
- **Movement-model tests** assert agreement with real constants from `src/` (e.g. the model never claims a jump the player's physics can't make); prior art: existing gameplay regression tests in `tests/`.
- **Golden-file test** for the TMX writer: a tiny fixed-seed level compared against a checked-in expected `.tmx`.
- End-to-end validation (map loads in LÖVE, level is beatable following the walkthrough) is a manual playtest step, deliberately outside the headless suite.

## Out of Scope

- Runtime/in-game generation, endless mode, or shipping the generator with the game.
- Generating `.tmx` art polish: decorative tile blending, custom art, per-level tilesets. Bland is the contract.
- A GUI, preview window, or interactive regenerate loop.
- Asymmetric dog/cat abilities (players are interchangeable).
- Validating or repairing hand-tweaked levels after generation.
- Difficulty *estimation* of arbitrary maps (the difficulty dial shapes construction; it does not grade existing levels).
- Teleporters and jump pads may be used by rules later, but no rule for them is required in v1.

## File Structure (if relevant)

```
tools/
  generate.sh              # launcher (arg passthrough, finds LuaJIT + Tiled CLI)
  level_generator/
    main.lua               # CLI parsing, batch loop, output orchestration
    rng.lua                # seeded PRNG
    movement_model.lua     # reachability maths fed by src/ constants
    plan.lua               # solution-first objective/zone planner
    layout.lua             # zones → tile terrain, platforms, ladders
    rules/                 # one file per puzzle rule (pluggable)
    decorate.lua           # coins, enemies, background dressing
    tmx_writer.lua         # TMX XML emission
    walkthrough.lua        # solution steps emission
    export.lua             # Tiled CLI .lua export
res/map/generated/         # output: NN-seed.tmx, NN-seed.lua, NN-seed-solution.md
```

## Acceptance Criteria

- [ ] `tools/generate.sh --seed 42` produces a `.tmx`, a `.lua`, and a solution walkthrough; `love . map=generated/<name>.lua` loads and plays it.
- [ ] Following the walkthrough completes the level: all cages released, exit opens, both players can exit.
- [ ] Same seed and flags reproduce byte-identical output; different seeds differ.
- [ ] `--count N` emits N independent, individually reproducible levels.
- [ ] `--size` changes map dimensions; `--difficulty` visibly changes cage count, puzzle chain depth, hazard and enemy density.
- [ ] `--coop required` levels contain at least one puzzle unsolvable by a lone player; `--coop optional` levels are completable solo.
- [ ] Every key, cage, switch, and the exit is reachable under the game's real movement according to the movement model.
- [ ] Generated maps open cleanly in Tiled 1.12+ with the project tilesets/templates resolving.
- [ ] Adding a new puzzle rule requires only a new file in the rules directory (demonstrated by at least two rules sharing the interface).
- [ ] Generator fails with a clear message (non-zero exit) instead of emitting an unsolvable map.
- [ ] Headless tests for planner, movement model, TMX writer, and determinism pass via `./test.sh`.

## References

- ADR 0002 — Solution-first generation with a modular puzzle-rule library (`docs/adr/0002-solution-first-level-generation.md`)
- ADR 0001 — Pushable motion and snap model (constrains push-box/boulder rules)
- `CONTEXT.md` glossary — Cage objective, Level generator, Puzzle rule, Solution walkthrough, Solution-first generation
- Existing maps `res/map/ll1.tmx`, `ll2.tmx`, `sandbox.tmx` as structural prior art
