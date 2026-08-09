Status: pending

# Playable door in the sandbox

## What to build

- `./run.sh map=sandbox` shows a locked door with a switch that opens it.
- The door is authored from `res/templates/door.tx`, the way a level designer would place one.

## Files to create/modify

- `res/map/sandbox.tmx` — a `door` object and a `switch` object targeting it
- `tests/integration/tmx_golden_test.lua` — normalisation entry for the new objects
- `res/templates/door.tx` — only if authoring exposes a missing default

## Test approach

- `all_maps_load_test` must still pass with the new objects present.
- `tmx_golden_test` must still pass via a documented normalisation, not an edited golden.
- Manual: `./run.sh map=sandbox`, walk into the door, hit the switch, walk through.
- E2E: extend or add a headed scenario capturing a frame locked and a frame open, per `tests/README.md`.

## Acceptance criteria

- [ ] Sandbox contains a switch-wired door placed from the template
- [ ] A player can walk into the locked door, flip the switch and cross
- [ ] `./test-integration.sh` and `./test-e2e.sh` pass
- [ ] The golden fixtures are unmodified

## Blocked by

Slice 03. Land after slice 04 so the demo shows the final behaviour.

## Gotchas

- `tests/fixtures/golden/sandbox.lua` predates these objects, so the golden diff will fail on the extra objects. Add a numbered entry to `tmx_golden_test.lua`'s header list explaining exactly that, in the style of entries 4 and 5. Never add the objects to the golden by hand — it is a real Tiled export and its authenticity is the test's value.
- Place the door where the existing sandbox layout gives it a floor and headroom; a 3×3 sprite bleeds a full tile in every direction.
- Object ids must not collide with existing sandbox ids, and the switch's `target` property holds the door's id.
- The alternative — demoing in `fab1.tmx`, which no golden covers — is recorded in DECISIONS.md Q8 if the normalisation turns out to be more trouble than it is worth.
