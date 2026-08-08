Status: done

# Co-op dial: two-agent plans and separation puzzles

## What to build
**Built differently than planned (2026-08-08, DECISIONS.md Q15):** there's no "door" entity to hold open, so the shape is a walled-off **vault** (`tools/level_generator/coop.lua`) placed entirely beyond the layout's own width — structurally unreachable by walking or climbing — holding one plan objective's key+cage. The only way in is a teleport gated `enabled=false` by default, driven by a momentary pressure plate placed far away (the ground zone). This required the source seam issue 04 declined (`object.properties.enabled` now forwards into `Switchable`/`Usable` for `teleport.lua`; backward-compatible, no existing map authors that property) — the user approved it specifically for this issue since coop's acceptance criteria can't be met without a real gate. No two-agent dependency-graph solver was built or needed: unsolvability is structural (the vault has no walk/ladder path in) plus mechanical (`pressure_switch.lua` is momentary — it drives its target off the instant its weight leaves, so a lone player can never be on the distant plate and at the teleport at once). `--coop optional` (default) skips the vault entirely — unchanged, fully solo-solvable behaviour.

## Files to create/modify
- tools/level_generator/coop.lua (vault geometry: walls, interior positions)
- tools/level_generator/main.lua (vault wiring: teleport pair, pressure plate, reassigning one plan objective into the vault)
- tools/level_generator/walkthrough.lua (accepts a plan already filtered of the vault objective, plus an extra flourish-style step describing the coop requirement)
- src/entities/teleport.lua (the `enabled` forwarding seam)

## Test approach
Headless: the vault's wall cells always sit beyond `layout.width` (never overlapping terrain/ladders/hazards); the vault forms a fully enclosed box; `--coop required` places exactly one pressure switch and one `enabled=false` teleport; every non-vault objective still sits on a normal zone. `tests/unit/teleport_start_disabled_test.lua` covers the seam itself (constructs a real headless `Teleport`, asserts the default is unchanged and `enabled=false` actually starts blocked). Integration: a generated coop level's vault teleport starts disabled and the pressure plate flips `usable.enabled` live, matching `pressure_switch.lua`'s real momentary behaviour. Manual: attempt a `required` level solo (must be stuck at the vault), then co-op.

## Acceptance criteria
- [x] `--coop required` levels contain ≥1 genuinely two-player puzzle, true by construction (structural unreachability + momentary plate), not a solver
- [x] `--coop optional` levels completable solo (default behaviour, untouched)
- [x] Walkthrough calls out the coop requirement and which player does what
- [x] Pressure-switch mechanics match shipped game behaviour exactly (momentary, weight tolerance) — no changes to pressure_switch.lua were needed

## Blocked by
04. External blocker (pushables/enemies) resolved before implementation started (see HANDOFF.md).
