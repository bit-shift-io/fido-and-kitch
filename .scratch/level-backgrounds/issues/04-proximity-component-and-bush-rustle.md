Status: pending

# Proximity component + bush rustle

## What to build
Generic `Proximity` component (`src/components/proximity.lua`):
- Config: `radius` (number), `targetTypes` (array, default {"player"})
- Each update: query world for targets within radius (read-only, no colliders created)
- Emits `proximity_enter(entity)` and `proximity_exit(entity)` signals on target enter/exit
- Entity-agnostic — any entity can use it

Bush prop layer adds proximity:
```lua
{ type = "props", name = "bushes", template = "bush", count = 6,
  region = {x=0, y="ground_y-120", w="map_width", h=120},
  depth = 0.3, windScale = 0.5,
  motion = { shake = { strength = 0.15, decay = 3.0 } },
  proximity = { radius = 48, react = "shake" } }
```
- `proximity.react = "shake"` → on enter, trigger `motion.shake` impulse (decays per `decay`)

Motion`decay`).
- Bush template already has `motion.shake` config.

## Files to create/modify
- src/components/proximity.lua (new)
- src/components/motion.lua (add shake trigger API)
- src/entities/bush.lua (wire proximity + shake)
- src/backgrounds/forest.lua (add bushes prop layer with proximity)
- res/map/sandbox.tmx + .lua (update background property)
- tests/unit/proximity_test.lua (new)

## Test approach
Headless: component fires enter exactly when player crosses radius, exit when leaving; no signals while player stays outside; bush triggers shake on enter and returns to rest after decay; works with both players. Uses existing kill-zone/ladder query test patterns.

## Acceptance criteria
- [ ] Bush rustles (shake) when player passes within radius, then settles
- [ ] Radius and enablement set via preset config (template/object properties)
- [ ] Proximity component is generic (no bush-specific logic inside it)
- [ ] Bush still has no collider; movement unaffected
- [ ] Works with both players

## Blocked by
03 (bush prop + motion.shake must exist). Independent of 02 — can run in parallel.