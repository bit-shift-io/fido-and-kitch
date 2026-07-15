Status: pending

# Pushable puzzle rules (box, boulder)

## What to build
Two new rule modules using the shipped pushable props per ADR 0001: **box-fills-hole** (push a box along a clear grounded run into a one-tile hole to bridge a gap or reach height) and **boulder-variants** (boulder rolled to rest as a step, or seated on a pressure switch as a permanent weight). Construction guarantees the push is physically possible: grounded run-up, no obstructions, hole within reach, and the prop can never end up somewhere that makes the level unwinnable (per the snap/fall model). Demo: a level whose walkthrough includes pushing a box into a hole to reach a cage.

## Files to create/modify
- tools/level_generator/rules/ (box-fills-hole, boulder rules)
- tools/level_generator/movement_model.lua (push feasibility checks)

## Test approach
Headless: push-path feasibility (contiguous ground, no walls/props in the run, pusher has standing room); irreversibility audit — no reachable prop state strands the solution (e.g. box pushed the wrong way off a ledge still leaves a route, or the rule forbids that geometry); rule conformance auto-test covers the new files. Manual: play a seed exercising each rule.

## Acceptance criteria
- [ ] Box-fills-hole levels completable per walkthrough with real pushable physics
- [ ] No generated geometry lets a prop reach a state that makes the level unwinnable
- [ ] Boulder rule produces at least one working pattern (step or switch weight)
- [ ] Rules added without core generator changes

## Blocked by
04. Also blocked externally: pushables (push box, boulder) must be implemented in the game first.
