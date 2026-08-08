Status: done

# Pushable puzzle rules (box, boulder)

## What to build
Two pushable mechanics using the shipped `push_box`/`boulder` entities (no ADR 0001 exists — see HANDOFF.md; behaviour verified directly against `src/components/pushable/pushable.lua`). **Built as one required mechanic plus one rules/ flourish (2026-08-08), not two `rules/` files** — `rules/`'s contract is "always non-gating" (DECISIONS.md Q14), and box-fills-hole is meant to actually gate an objective (per this issue's own acceptance criteria), so it's a standalone module like `coop.lua`'s vault:
- **box-fills-hole** (`tools/level_generator/pushables.lua`, always applied): additive, beyond the ground zone's own width, like the coop vault — never touches Layout's zones. A push_box starts flush against the ground zone's right edge; pushing it one tile right drops it into a one-tile gap where it settles as solid ground (`Pushable:update`'s "supported is decided by the centre-x alone" snap-to-grid behaviour), bridging to a small far platform holding one relocated key+cage. A kill zone under the gap (`deathType='pit'`) makes falling in before it's bridged a recoverable death, not a permanent stranding (there's no ladder back up from the world's bottom boundary).
- **boulder-weighs-plate-teleport** (`tools/level_generator/rules/boulder_weighs_plate.lua`, an optional flourish): a boulder rolled onto a pressure plate seats there permanently (`seatOnPlate`) and counts as weight (`pressure_switch.lua`'s `hasWeight` recognises `isPushable`), driving an optional teleport shortcut. Needed an idle push_box as a "stopper" immediately past the plate — roll velocity has no friction/decay (`nextRollVelocity`), so an unobstructed boulder rolls forever and never settles on its own.

## Files to create/modify
- tools/level_generator/pushables.lua (box-fills-hole geometry)
- tools/level_generator/rules/boulder_weighs_plate.lua (flourish)
- tools/level_generator/main.lua (wiring: relocates one plan objective behind the bridge, extends map width additively)

## Test approach
Headless: the gap sits exactly one column past the ground zone; the box spawns with a clear run-up; the guard-rail kill zone is positioned under the gap; rule conformance covers the new flourish file automatically. Integration: a real player push (`FakeInput`, mirroring `tests/integration/boulder_test.lua`) actually settles the box as static walkable ground, and actually seats the boulder on its plate so `pressure_switch:hasWeight()` reports true — a directly-set velocity doesn't work here since `Pushable:update` recomputes velocity from real overlapping pushers every frame.

## Acceptance criteria
- [x] Box-fills-hole levels completable per walkthrough with real pushable physics (verified: pushing settles the box as static ground)
- [x] No generated geometry lets a prop reach a state that makes the level unwinnable (additive placement never touches existing zones; the gap's kill zone makes a premature fall recoverable)
- [x] Boulder rule produces a working pattern (permanent plate weight, driving an optional teleport)
- [x] The boulder flourish is added without core generator changes (auto-discovered via `rule_set.lua`); box-fills-hole is a deliberate core addition since it's meant to gate, unlike `rules/`

## Blocked by
04. External blocker (pushables/enemies) resolved before implementation started (see HANDOFF.md).
