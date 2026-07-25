Status: pending

# Pressure switch mechanic integration test

## What to build

A contributor can now write a test covering a real interactive mechanic end-to-end: a player walking onto a pressure switch fixture map, standing on the plate, and the switch's target firing — proving the harness handles collision-driven component wiring (`Collider`, the pressure switch component, its `target` + `:switch()` mechanism), not just raw movement.

Concretely:
- A new fixture map (`tests/integration/fixtures/pressure_switch.tmx` + exported `.lua`): a flat room with one pressure switch plate and a simple target entity whose `:switch()` call is observable (e.g. a door-like entity or a minimal target with a detectable state flag) within the switch's authored range.
- `tests/integration/pressure_switch_test.lua`: spawn a player, walk them onto the plate via `FakeInput`/`holdFor`, assert the target fired (via a query helper); walk the player off, and — since the switch is momentary by default per its existing behaviour — assert the target's momentary re-drive behaviour matches expectations once the plate is vacated.

## Files to create/modify

- tests/integration/fixtures/pressure_switch.tmx
- tests/integration/fixtures/pressure_switch.lua
- tests/integration/pressure_switch_test.lua
- tests/integration/support/queries.lua (extend with a target-state accessor if the existing helpers from issue 02 aren't sufficient)

## Test approach

Assert via the target entity's observable state (through a query helper), not by reaching into the pressure switch component's internals. Cover: switch activates when a player is substantially on the plate, and the momentary behaviour on leaving (per the existing "Pressure switch" glossary entry in `CONTEXT.md`).

## Acceptance criteria

- [ ] `pressure_switch` fixture map loads and contains a plate + target reachable by a walking player.
- [ ] Test asserts the target fires when the player is on the plate.
- [ ] Test asserts the momentary-switch behaviour when the player leaves the plate.

## Blocked by

02-input-controller-and-movement-test
