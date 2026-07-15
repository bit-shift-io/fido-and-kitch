Status: pending

# Hazard placement (kill zones)

## What to build
Levels gain danger: water pools and pits emitted as kill-zone rect objects with `deathType` properties, plus matching visual water tiles so the drawn hazard and the gameplay volume line up. Placement is constrained by the plan: the walkthrough route never *forces* a death — hazards sit in gaps the solution jumps over, below optional areas, or guarding shortcuts. Hazard density scales with `--difficulty`. Demo: a generated level where careless play dies, careful play following the walkthrough never must.

## Files to create/modify
- tools/level_generator/decorate.lua (hazard placement)
- tools/level_generator/plan.lua (route-safety constraint)
- tools/level_generator/tmx_writer.lua (kill objectgroup + water layer)

## Test approach
Headless: for many seeds, no solution-path traversal segment intersects a kill zone in a way the movement model can't clear; kill zones always carry a `deathType`; visual water tiles and kill rects coincide. Manual: deliberately fall into hazards (lives pool decrements, respawn works), then complete via the walkthrough.

## Acceptance criteria
- [ ] Kill zones emitted with death types on their own objectgroup, matching hand-made map conventions
- [ ] Walkthrough route never requires touching a kill zone
- [ ] Visual hazard tiles align with kill volumes
- [ ] Hazard density scales with difficulty (difficulty 1 may have none)

## Blocked by
03
