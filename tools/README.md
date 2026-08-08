# Procedural Level Generator

A standalone, offline CLI tool that generates complete, playable-but-bland
`Fido and Kitch` levels for hand-tweaking in Tiled. Never part of the shipped
game or its runtime.

## Usage

```sh
sh tools/generate.sh --seed 42
sh tools/generate.sh --size large --difficulty 5 --coop required --count 3
```

Output goes to `res/map/generated/<seed>.tmx` plus a matching
`<seed>-solution.md` walkthrough. The game loads `.tmx` directly, so a
generated level is immediately playable:

```sh
./run.sh map=generated/42.tmx
```

`res/map/generated/` is gitignored — candidates are disposable by default.
Keep one by moving/renaming it into `res/map/` proper (or `git add -f`).

## Flags

| Flag | Values | Default | Effect |
|---|---|---|---|
| `--seed` | integer | random (always printed) | Deterministic: same seed + flags ⇒ byte-identical output. |
| `--count` | positive integer | `1` | Emits N levels; each item's seed is independently derived from the base seed, so any one of them can be regenerated alone later. |
| `--size` | `small`\|`medium`\|`large` | `medium` | Map dimensions and platform count. |
| `--difficulty` | `1`–`5` | `1` | Scales hazard density, optional rule-flourish count, and enemy density — all `0` at difficulty 1. |
| `--coop` | `optional`\|`required` | `optional` | `required` seals one key+cage pair behind a vault only a distant, held-down pressure plate can open — see below. |

## What a generated level contains

- **Terrain**: a ground row plus a chain of platforms connected by ladders
  (`layout.lua`). The player has no jump in this game — every zone is
  reachable only by walking and/or climbing, guaranteed by construction
  (`movement_model.lua`).
- **Objectives**: one colored key + matching cage per zone pair
  (`plan.lua`). Using every cage opens the exit automatically (the game's
  real `all_cages_unlocked` mechanism — there's no bird-path or
  `actor_count` countdown to route through).
- **Hazards** (`--difficulty`-scaled): kill zones in ladder gaps. The
  intended route (platform → ladder → platform) never touches one; falling
  off an edge instead of climbing does.
- **Puzzle-rule flourishes** (`--difficulty`-scaled, `tools/level_generator/rules/`):
  optional, never-required interactions — a switch that can disable a
  teleport shortcut, a switch that can disable a jump-pad hop, a boulder
  that permanently weighs a pressure plate. Auto-discovered: drop a new
  file in `rules/` implementing `{id, canApply(layout), apply(rng, layout, startId)}`
  and it's picked up with no other changes.
- **Box-fills-hole**: a push_box beside a one-tile gap past the ground
  zone's edge, bridging to a small far platform holding one relocated
  key+cage. A kill zone under the gap makes falling in before it's bridged
  a recoverable death, not a dead end.
- **`--coop required`**: a walled-off vault entirely beyond the normal
  layout, holding one key+cage, reachable only through a teleport that
  starts disabled and is driven by a momentary pressure plate placed far
  away. The plate releases the instant its weight leaves, so one player
  physically cannot hold it *and* reach the teleport — solvable only by
  construction, not a puzzle a solo player can brute-force.
- **Dressing**: a random real background (`night_forest`/`mushroom_cave`/`sky`),
  one coin per zone, and `--difficulty`-scaled enemies (spider/robot),
  never placed on a ladder column.

## Tests

Headless tests live alongside the rest of the project's suite:

```sh
./test-unit.sh tests/unit/level_generator_*.lua
./test-integration.sh tests/integration/level_generator_*.lua
```

## Further reading

The full design rationale — including several corrections made against
what the game's code actually does versus what earlier docs assumed — is
in `.scratch/procedural-level-generation/DECISIONS.md` and `HANDOFF.md`
while that planning directory exists.
