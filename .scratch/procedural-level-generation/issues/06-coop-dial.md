Status: pending

# Co-op dial: two-agent plans and separation puzzles

## What to build
`--coop required|optional` becomes real. The planner gains a two-agent solution model (players are interchangeable): each walkthrough step is assigned to P1/P2, and `required` levels include at least one rule instance that a lone player cannot complete — canonically a momentary pressure switch placed far from the door it holds open, with no substitutable weight nearby. `optional` restricts plans to single-agent-solvable and the walkthrough notes it's soloable. Demo: a `required` seed where one player demonstrably cannot finish alone, and both players complete it per the walkthrough.

## Files to create/modify
- tools/level_generator/plan.lua (two-agent model, step assignment)
- tools/level_generator/rules/ (pressure-switch-separation rule)
- tools/level_generator/walkthrough.lua (per-player step labels)

## Test approach
Headless: for `required` seeds, a single-agent solver over the plan graph fails while the two-agent plan succeeds; for `optional` seeds the single-agent solver succeeds; the separation rule never places a pushable weight within substitution range of its plate. Manual: attempt a `required` level solo (must be stuck), then co-op.

## Acceptance criteria
- [ ] `--coop required` levels contain ≥1 genuinely two-player puzzle (verified programmatically per plan)
- [ ] `--coop optional` levels completable solo
- [ ] Walkthrough steps labelled per player
- [ ] Pressure-switch rule matches shipped game behaviour (momentary, weight tolerance)

## Blocked by
04. Also blocked externally: pressure switch must be implemented in the game first.
