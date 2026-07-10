Status: pending

# Proximity component and bush rustle

## What to build
When a player runs past a bush in sandbox, the bush rustles — a brief procedural shake/squash that decays. Detection comes from a new generic `Proximity` component: configured with a radius, it monitors distance to players each update (using the established player-position/world-query patterns, read-only) and emits enter/exit signals. The bush enables it via template/object properties (e.g. `reactToPlayer=true`, `reactRadius`) and triggers its rustle on enter.

The component is entity-agnostic so future props (or other entities) can reuse it. Sandbox map updated: bush template/objects carry the proximity properties.

## Files to create/modify
- src/components/proximity.lua (new)
- src/entities/bush.lua (rustle motion + component wiring)
- res/templates/bush.tx (default `reactToPlayer`/`reactRadius` properties)
- res/map/sandbox.tmx + res/map/sandbox.lua (bush properties)
- tests/ (new test file)

## Test approach
Headless: component fires enter exactly when a player crosses the radius and exit when leaving; no signals while the player stays outside; bush enters its rustle state on enter and returns to rest after the decay; component works with both players. Prior art: kill-zone/ladder query tests.

## Acceptance criteria
- [ ] Bush rustles when a player passes within its radius, then settles
- [ ] Radius and enablement are set via Tiled properties, defaulted in the template
- [ ] Proximity component is generic (no bush-specific logic inside it)
- [ ] Bush still has no collider; movement is unaffected

## Blocked by
02 (bush prop). Independent of 03 — can run in parallel with it.
