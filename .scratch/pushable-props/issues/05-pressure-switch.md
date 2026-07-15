Status: pending

# Pressure switch: weight-activated, drives a target

## What to build
A `pressure_switch` prop: a single-tile (32×32) sensor plate that activates while a qualifying weight — a player or a pushable — is substantially on it, and drives a target entity through the same `target` + `:switch()` mechanism the lever `switch` uses. "Substantially on it" = the weight's centre-x is within a small tolerance of the plate tile's centre while overlapping the plate. Activated while ≥1 qualifying weight is on; deactivated when the last one leaves. Momentary (default): re-drive `target:switch()` on both activation and deactivation. Latching (`latching=true`): drive once on first activation, never on release. When a box is pushed onto the plate and the player stops pushing, if the box centre-x is within tolerance the box snaps to the plate tile centre (snap on release, not mid-push); the player can push it back off. Placeholder: a flat plate quad that changes colour when active.

## Files to create/modify
- src/entities/pressure_switch.lua (new — sensor Collider, weight-detection each update via bounds query, target drive mirroring src/entities/switch.lua, momentary/latching state, colour-change draw)
- src/components/pushable.lua (snap-to-plate on push-release when within tolerance of a plate — the plate exposes its tile-centre; box queries for an overlapping plate like player queries for kill zones)
- res/templates/pressure_switch.tx (new — `type="pressure_switch"`, `target` object property, `latching` bool default false)
- res/map/sandbox.(tmx|lua) (place a plate wired to an existing switchable target, e.g. a cage/door, for demo)
- tests/pressure_switch_test.lua (new, register in tests/run.lua)
- (reference) src/entities/switch.lua (target + :switch() drive), src/entities/cage.lua (a switchable target), src/player/player.lua queryKillZone (bounds-query pattern), src/utils/rect.lua

## Test approach
Headless tests: activation predicate (centre-x within tolerance + overlap → on; off-centre beyond tolerance → not on); multi-weight count (two weights → still one activation; deactivates only when the last leaves); momentary drives target on activate and deactivate; latching drives once and holds. Manual: push a box onto the plate → target toggles and box snaps on release; step the player onto/off the plate → momentary toggles; a latching plate stays on after the weight leaves.

## Acceptance criteria
- [ ] A player or a pushable substantially on the plate (centre-x within tolerance) activates it.
- [ ] The plate drives its `target` via `:switch()` (works with an existing switchable target).
- [ ] Momentary (default) deactivates and re-drives the target when the last weight leaves.
- [ ] Latching stays on after first activation and does not release.
- [ ] Two weights count as one activation; it deactivates only when the last leaves.
- [ ] A box pushed onto the plate snaps to the plate tile centre on push-release and can be pushed back off.
- [ ] The plate changes colour when active.
- [ ] Activation/momentary/latching/multi-weight logic covered by passing headless tests.

## Blocked by
Issue 03 (needs a landed/pushable box to test with; snap-to-plate reuses the snap helper). Boulder (issue 04) not required but activates the plate too once present.
