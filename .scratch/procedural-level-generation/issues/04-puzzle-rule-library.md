Status: pending

# Modular puzzle-rule library + difficulty-driven chain depth

## What to build
Puzzle patterns become pluggable modules in `tools/level_generator/rules/`, each implementing one uniform interface: requirements, effects (what it unlocks), expansion into terrain/entities, and contributed walkthrough steps. The planner composes rules into chains (e.g. lever switch opens the door guarding a key, which opens a cage…), with `--difficulty 1..5` controlling chain depth and rule complexity. Ship at least two rules to prove the interface: **lever-switch-opens-remote-door** and **bird-flicks-switch-on-exit-path** (the bird's path routes past a switch with an exec action). Demo: two levels at difficulty 1 and 5 showing visibly shallower/deeper chains, and a third rule stub added without touching core files.

## Files to create/modify
- tools/level_generator/rules/ (interface + rule files)
- tools/level_generator/plan.lua (rule composition)
- tools/level_generator/walkthrough.lua (rule-contributed steps)

## Test approach
Headless: rule interface conformance test run against every file in `rules/` (new rules get tested for free); composed chains remain acyclic and ordered; difficulty monotonically increases chain depth across seeds; a dummy test-only rule registers without core changes (proves pluggability). Manual: play a difficulty-5 seed following the walkthrough.

## Acceptance criteria
- [ ] ≥2 real rules share the interface; adding a rule = adding one file
- [ ] `--difficulty` changes chain depth measurably and monotonically
- [ ] Walkthrough correctly interleaves rule-contributed steps
- [ ] Bird-flicks-switch levels complete correctly in-game (bird's exec fires the switch)
- [ ] Rule conformance test auto-covers new rule files

## Blocked by
03
