Status: done

# Modular puzzle-rule library + difficulty-driven chain depth

## What to build
**Scope correction (2026-08-08, DECISIONS.md Q14):** no shipped entity acts as a simple closed-until-switched gate — `Switchable`'s only real targets (`teleport`, `jump_pad`, `drawbridge`, `pressure_switch`) all hardcode `enabled=true` at construction with no way to author a start-disabled state from Tiled data, and neither `bird-flicks-switch-on-exit-path` (no path-following/exec on the bird NPC) nor a real "lever opens door" rule are achievable without a source change. Per user direction, no gating rules this pass, no Layout/source changes: rules are optional, non-gating flourishes using entities that work correctly today, proving the pluggable interface rather than real puzzle depth. Puzzle patterns become pluggable modules in `tools/level_generator/rules/`, each implementing one uniform interface (`id`, `canApply(layout)`, `apply(rng, layout, startId)` → objects + a walkthrough step), auto-discovered by listing the directory (a new rule file needs no registration elsewhere). Ship two rules: **switch-disables-teleport-shortcut** (a switch that can disable one leg of an optional teleport shortcut between two zones) and **switch-disables-jump-pad-hop** (a switch that can disable an optional jump-pad hop within a wide-enough zone). `--difficulty 1..5` controls how many flourish instances get applied (monotonically, e.g. 0 at difficulty 1-2, 1 at 3-4, 2 at 5) — not chain depth, since there's no dependency chain to deepen. Demo: two levels at difficulty 1 and 5 showing zero vs. multiple flourishes, and a third rule stub added by only adding a file.

## Files to create/modify
- tools/level_generator/rules/ (interface + rule files)
- tools/level_generator/plan.lua (rule composition)
- tools/level_generator/walkthrough.lua (rule-contributed steps)

## Test approach
Headless: rule interface conformance test run against every file discovered in `rules/` (new rules get tested for free); `--difficulty` monotonically increases flourish count across seeds; a dummy test-only rule registers without core changes (proves pluggability). Manual: play a difficulty-5 seed, confirm flourishes are optional (level still completable ignoring them) and the switches/teleports/jump-pad work as expected.

## Acceptance criteria
- [ ] ≥2 real rules share the interface; adding a rule = adding one file, no registration elsewhere
- [ ] `--difficulty` changes flourish count measurably and monotonically
- [ ] Walkthrough correctly interleaves rule-contributed steps
- [ ] Flourishes never block completability (level solvable with every flourish's switch left untouched)
- [ ] Rule conformance test auto-covers new rule files

## Blocked by
03
