# Door entity

## Problem

- No entity gates horizontal passage on a switch — the drawbridge only spans a pit.
- Level design wants "hit the switch to get through", the most common lock-and-key shape.
- Exit-door naming is inconsistent: the type is `exit_door`, but its art is `entity_door.png`, its template is `exit.tx`, and its Tiled objects are named `exit`.

## Solution

- A new `door` entity: locked (solid) by default, unlocked (passable) while its switch reports `on`.
- Locked blocks players, enemies and pushable props alike — no entity-type eligibility.
- Rename every exit-door asset and object name to `exit_door`, freeing `entity_door.png` for the new entity.

## Out of Scope

- Multi-target switches. One switch drives one door; a level needing two doors uses two switches.
- Latching. The door mirrors switch state both ways; a momentary pressure switch only holds it open while held.
- Keys, usables or any unlock route other than a linked switch.
- Bespoke door art and audio. The drawbridge's are copied as placeholders.
- Renaming `ExitDoor:exitThroughDoor` / `exitInstant` — maps call those from `finish` property snippets.

## Cross-cutting Constraints

- Door state names mirror the drawbridge exactly: `closed`, `opening`, `open`, `closing`.
- The permissive state wins during transitions. For the drawbridge permissive means solid (`isDeckSolid(state) = state ~= 'closed'`); for a door it means passable, so `isDoorSolid(state) = state == 'closed'`.
- Solidity is toggled via `Collider:setSensor`, never by adding or removing colliders.
- Pure decision helpers stay private locals, exposed to their test file only through a `Door._internal` seam — the `Drawbridge._internal` / `PressureSwitch._internal` pattern.
- Sprite footprint is decorative bleed only. It is never a hint about what blocks or what can be stood on.

## Acceptance Criteria

- [ ] A door authored from `res/templates/door.tx` starts locked and blocks a walking player, an enemy and a pushed box.
- [ ] Flipping its linked switch `on` lets all three through; flipping it `off` blocks them again.
- [ ] A switch flipped `off` while an entity stands in the doorway cannot seal that entity in.
- [ ] `res/img/entity_door.png` is the door's art; the exit door draws `res/img/entity_exit_door.png`.
- [ ] Every Tiled exit-door object is named `exit_door` and instanced from `res/templates/exit_door.tx`.
- [ ] The exit door plays a real sound on open instead of warning about a missing file.
- [ ] `./test-unit.sh`, `./test-integration.sh` and `./test-e2e.sh` all pass.

## References

- `AGENTS.md` § Conventions — new map entity, `_internal` seam, `collider.walkable`
- `CONTEXT.md` — Door, Exit door, Doorway
- `src/entities/drawbridge.lua` — the state model this entity mirrors
- `src/components/switchable.lua` — the switch contract
- `.scratch/drawbridge/` — the original drawbridge design, where the transition rule was settled
