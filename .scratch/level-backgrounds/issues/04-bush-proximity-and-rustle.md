Status: pending

# Bush prop + proximity component + rustle

## What to build
Bush prop layer with proximity:
```lua
props = {
  {
    name        = "bushes",
    template    = "bush",
    count       = 8,
    region      = {x = 0, y = "ground_y - 64", w = "map_width", h = 64},
    depth       = 0.9,
    windScale   = 0.5,
    motion      = { sway = { strength = 0.01, speed = 0.7 } },
    proximity   = { radius = 48, react = "shake" },
  },
}
```

Generic `Proximity` component (`src/components/proximity.lua`):
- Config: `radius`, `targetTypes` (default {"player"})
- Each update: query world for targets within radius (read-only, no colliders)
- Emits `proximity_enter(entity)` and `proximity_exit(entity)` signals
- Entity-agnostic — any entity can use it

Bush entity:
- Adds Proximity component with config from preset
- On `proximity_enter`, triggers `motion.shake` impulse (decaying shake/squash)
- Shake in `motion.lua`: `shake = {strength, decay}` — `strength` = max angle/scale offset, `decay` = seconds to settle

Bush template: `res/templates/bush.tx` referencing `props.tsx` bush tile (new tile).
Bush art: `res/img/bush_1.png` → `props.tsx`.

## Files to create/modify
- src/components/proximity.lua (new)
- src/components/motion.lua (add shake implementation)
- src/entities/bush.lua (wire proximity + shake)
- res/templates/bush.tx (new)
- res/img/bush_1.png (new)
- res/tilesets/props.tsx (add bush tile)
- src/backgrounds/night_forest.lua (add bush prop layer with proximity)
- res/map/sandbox.tmx + .lua
- tests/unit/proximity_test.lua (new)

## Test approach
Headless: component fires enter exactly when player crosses radius, exit when leaving; no signals while player stays outside; bush triggers shake on enter and returns to rest after decay; works with both players. Uses existing kill-zone/ladder query test patterns.

## Acceptance criteria
- [ ] Bush rustles (shake) when player passes within radius, then settles
- [ ] Radius and enablement set via preset config
- [ ] Proximity component is generic (no bush-specific logic inside it)
- [ ] Bush still has no collider; movement unaffected
- [ ] Works with both players

## Blocked by
03 (bush prop + motion.shake must exist). Independent of 02 — can run in parallel.