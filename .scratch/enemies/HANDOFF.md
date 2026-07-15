# Handoff — Enemies (Spider & Robot)

## Summary

Two Tiled-placed enemies built on one shared AI base. Both chase the nearest valid player at ~70% player speed under player-like physics, navigating by axis alignment (walk to close X; climb a ladder they already overlap to close Y — no pathfinding). The **robot** shoves overlapping players sideways as a gentle, hazard-blind nuisance; the **spider** wraps its victim in a web that freezes them for ~20s then fades. A per-enemy, per-player **harassment ban** (~30s; spider: on wrap, robot: after ~10s chasing one target) forces attention rotation; with no valid target the enemy wanders. Players' only counterplay is a head stomp: ~10s stun + bounce. Everything is placeholder quads. Enemies never directly kill.

Full spec: [PRD.md](PRD.md). Rationale: [DECISIONS.md](DECISIONS.md). Glossary entries added to `CONTEXT.md`: Enemy, Harassment ban, Web wrap, Head stomp. No ADRs — the contact-model and ban decisions are reversible and are logged in DECISIONS.md instead.

## Implementation order

1. **01-enemy-chases-on-x** — foundation: entity base, brain module, robot placement, X chase.
2. **02-ladder-climbing** and/or **03-robot-shove** — independent of each other; either order. 03 makes the robot demoable as a complete enemy sooner.
3. **04-bans-and-wander** — completes the robot's behaviour loop.
4. **05-spider-wrap** — biggest slice; needs the ban API from 04 and the shove-immunity flag consumed by 03.
5. **06-head-stomp-stun** — anytime after 01; last is fine.

## Implementer notes / gotchas

- **Player velocity reset**: `WalkIdleState` + `PlayerMovement.decideHorizontalMovement` (src/player/) rewrite the player's horizontal velocity from input every frame. The robot's shove must be a per-frame position offset or applied after player movement — a one-off velocity impulse will be silently eaten.
- **Testability seam pattern**: mirror `src/player/player_movement.lua` — pure decision functions with no LÖVE/globals dependencies, tested in `tests/<name>_test.lua`, run via `./test.sh`. The runner is dependency-free; see tests/README.md.
- **Entity conventions**: `Class{__includes = Entity}` + `Entity.init(self)`; components via `addComponent`; a Tiled object `type` must match a `src/entities/<type>.lua` filename. The runtime-spawned web entity must not collide with that convention (either place it outside `src/entities/` or ensure no Tiled object ever uses type `web`).
- **Player-sensing**: ladder queries to copy are `Player:queryLadder` / `queryLadderBelow` (src/player/player.lua); ladders are static sensor colliders. Players are reachable via the global `Game`/map wiring — follow how kill zones find players.
- **Non-solid to players, solid to world**: enemy collider must collide with world geometry/pushables but only sense players (the bump backend emulates Box2D-ish semantics; keep both backends' behaviour aligned per AGENTS.md).
- **Two-player testing**: bans/retargeting only show with both players — P1 arrows + right-shift, P2 WASD + Q. Use `love . debug drawphysics map=sandbox.lua`.
- **Tuning defaults** (Tiled property overridable): speed 70, wrap 20s, ban 30s, robot chase-to-ban 10s, stun 10s. Keep as named constants near the brain.
- **State machine component** (`src/components/state_machine.lua`): accepts `stateClasses` wired to the entity; unknown method calls proxy to the current state — same pattern the player FSM uses; add `WrappedState` alongside the existing player states.
