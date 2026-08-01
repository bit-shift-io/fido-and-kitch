Status: pending

# Wire sandbox's switch to a new door

## What to build

In `res/map/sandbox.tmx`:

- Add a new `door` object (using the `door.tx` template from issue 01)
  positioned near the existing switch (object id 44), placed so it visibly
  blocks a short passage for the demo.
- Override the switch's `target` property on its instance (object id 44) to
  point at the new door object's id, instead of inheriting the template
  default (`target=43`, the exit door — which has no `:switch()` handler and
  currently makes the switch a no-op).

After this change, flipping the sandbox switch in-game opens the new door;
flipping it again closes it.

## Files to create/modify

- res/map/sandbox.tmx

## Test approach

- No new automated test is expected to assert on `sandbox.tmx` specifically
  beyond confirming the map still parses (existing map-loading tests, if
  any, should continue to pass unmodified).
- Verified by playing the sandbox map: approach the door while closed and
  confirm it blocks; flip the switch and confirm the door opens and becomes
  passable; flip it again and confirm the door closes and blocks again,
  including while a player or pushable is mid-crossing during the closing
  animation.

## Acceptance criteria

- [ ] `sandbox.tmx` contains a new `door` object near the switch.
- [ ] The switch's `target` property is overridden to the new door's object
      id.
- [ ] Flipping the switch in-game opens/closes the door as expected.
- [ ] The map still loads without errors.

## Blocked by

01-door-entity.md
