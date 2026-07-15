# Enemies: Spider & Robot

## Problem Statement

Levels currently only threaten players with static hazards (kill zones). There is no active opposition — nothing that reacts to the players, pressures their route choices, or forces the co-op pair to coordinate under time pressure. Levels feel safe once the layout is learned.

## Solution

Two roaming enemies the designer can drop into any level from Tiled, both built on one shared "hinder the nearest player" AI:

- **Spider** — intercepts the nearest player and, on contact, wraps them in a web that freezes them in place for ~20 seconds before fading out. It then moves on to harass the other player.
- **Robot** — intercepts the nearest player and shoves them around on contact, a persistent nuisance rather than a lethal threat.

Both enemies navigate by axis alignment: walk to close the X gap to the target, and climb any ladder they happen to be overlapping when the target is above/below to close the Y gap. They obey player-like physics (gravity, walls, can fall off edges) and move at ~70% of player walk speed, so they only catch players who are cornered, climbing, or distracted.

Neither enemy directly kills; they cost the players *time* (web) and *control* (shove), which becomes danger only in combination with the level's existing hazards.

A shared **harassment ban** keeps them from being oppressive: once an enemy has successfully harassed a player (spider: on wrapping them; robot: after ~10s of chasing them), it is banned from targeting that player for ~30 seconds and must go bother someone else — or wander if no valid target exists. **Head stomp**: a player landing on an enemy from above stuns it for ~10s and bounces off, giving co-op counterplay (one player stomps to free up space while the other works).

## User Stories

1. As a level designer, I want to place a `spider` or `robot` object in Tiled like any other entity, so that adding opposition to a level requires no code.
2. As a level designer, I want to place any number of enemies per level, so that difficulty is a placement decision.
3. As a player, I want enemies to chase whichever of us is nearest, so that threat is shared and readable.
4. As a player, I want enemies to be slower than my walk speed, so that I can always escape in open space.
5. As a player caught by the spider, I want to be visibly wrapped and frozen for ~20 seconds while the web fades, then continue as normal, so that being caught is a setback, not a death.
6. As the wrapped player's partner, I want the spider to leave the wrapped player alone and come after me, so that both of us stay engaged.
7. As a player who was just harassed, I want the enemy banned from targeting me for ~30 seconds, so that I can't be perma-locked by one enemy.
8. As a player near the robot, I want it to nudge me sideways while we overlap, so that it disrupts precise movement without ever being an instant death.
9. As a player, I want the robot to give up on me after ~10 seconds of chasing (its ban kicks in), so that it eventually rotates its attention.
10. As a player, I want to stun an enemy for ~10 seconds by landing on it from above (with a small bounce), so that I have counterplay.
11. As a player, I want enemies with no valid target (everyone banned or wrapped) to wander/patrol near where they are, so that the level still feels alive and I can predict them.
12. As a player, I want enemies to use ladders they're standing on to climb toward me when I'm above or below them, so that vertical separation isn't a total escape.
13. As a player, I want a wrapped teammate to still be framed by the camera and still be killable by hazards, so that the world's rules stay consistent.
14. As a player, I want the robot's shove to be gentle enough that it can only endanger me through my own positioning mistakes, so that deaths still feel like my fault.
15. As a player, I want a wrapped player to be un-shovable (frozen means frozen), so that the robot can't exploit a webbed teammate.
16. As a developer, I want the AI's targeting, ban, and movement decisions in headless-testable modules, so that regressions are caught by `./test.sh`.

## Implementation Decisions

- **New entities**: `src/entities/spider.lua`, `src/entities/robot.lua` (Tiled object types `spider`, `robot`), plus a `web` runtime-spawned entity (not placed from Tiled).
- **Shared AI**: a common enemy "brain" module (pure-logic, headless-testable — same seam pattern as `PlayerMovement.decideHorizontalMovement`) covering:
  - *Target selection*: nearest alive, non-wrapped, non-banned player; re-evaluated continuously.
  - *Harassment bans*: per enemy-instance, per-player timers (~30s). Spider ban starts when a wrap lands. Robot ban starts after ~10s of cumulative pursuit of the same target.
  - *Movement decision*: walk toward target X; when overlapping a ladder and target Y differs beyond a threshold, climb toward target Y (opportunistic — no ladder route planning); resume X alignment when Y is as close as the ladder allows.
  - *Wander*: no valid target → amble/patrol around current position until a target becomes valid.
  - *Stun*: head-stomp detection (player falling, overlapping from above) → ~10s freeze, player bounces; stun does not create a ban.
- **Enemy body**: dynamic collider with gravity, solid vs. world (walls, ground, pushables), **sensor/overlap vs. players** — enemies never block player movement. Spider wrap and robot shove both trigger on overlap.
- **Robot shove**: while overlapping a valid target, applies a steady sideways displacement to the player. Must survive the player's per-frame velocity reset (see HANDOFF gotcha) — applied as position offset or post-movement velocity add.
- **Wrapped player**: new player FSM state (`WrappedState`) — all movement input ignored, gravity settles them to ground, still a camera framing target, still killable by kill zones, immune to robot shoves. ~20s duration; web visual fades out near the end; on expiry player returns to normal control. A just-freed player is covered by the wrapping spider's 30s ban; other enemies may target them.
- **Web**: runtime entity drawn over the wrapped player (placeholder quad with alpha fade).
- **Tuning**: constants in code with per-object Tiled property overrides (speed, wrapDuration, banDuration, chaseBanTime, stunDuration) — matching the existing `windScale`-style pattern. Defaults: speed 70 (player is 100), wrap 20s, ban 30s, robot chase-to-ban 10s, stun 10s.
- **Art**: placeholder coloured quads for spider, robot, and web (as push box / boulder did).
- **State machines**: use the existing `StateMachine` component with states like `ChaseState`, `WanderState`, `StunnedState` (and spider `ClimbState`/internal ladder handling mirroring player ladder use where practical).

## Testing Decisions

- Good tests here assert **decisions**, not rendering: which player gets targeted, when bans start/expire, which direction the enemy decides to move, when a ladder climb is chosen, when a wrap/shove/stun triggers.
- Modules under test: the shared enemy brain (targeting, bans, movement decision), robot chase-timer/ban logic, wrap timer/expiry, stomp detection geometry.
- Prior art: `tests/player_movement_test.lua`, `tests/lives_test.lua`, `tests/safe_position_test.lua` — dependency-free headless tests run via `./test.sh`.
- File location/naming: this project's convention — `tests/<module>_test.lua` (Lua project; the TS naming conventions don't apply).

## Out of Scope

- Real art/animation for spider, robot, or web (placeholders only).
- Pathfinding: enemies never plan routes or seek out ladders — ladder use is strictly opportunistic (already overlapping one).
- Enemies damaging or killing players directly; enemies interacting with pickups, switches, or pushable props beyond standing/colliding with them as world solids.
- Struggle-to-escape or rescue mechanics for the web (it purely times out).
- Killing enemies (stomp stuns only); enemy death/respawn.
- Spawners or triggered enemy entrances (placed-at-load Tiled objects only).
- Enemy-vs-enemy interactions beyond not being solid to each other.
- Sound effects.

## Acceptance Criteria

- [ ] A `spider` / `robot` Tiled object of any count spawns working enemies at level load.
- [ ] Enemies chase the nearest valid player at ~70% player speed, with gravity and wall collision, and can fall off edges.
- [ ] An enemy overlapping a ladder climbs it toward a target that is above/below.
- [ ] Spider overlap with a valid target wraps that player: frozen, input ignored, web drawn, frees after ~20s with a fade; wrapped player remains camera-framed and hazard-killable.
- [ ] After wrapping, the spider is banned from that player for ~30s and immediately retargets the other player.
- [ ] Robot overlap shoves the player sideways (gentle, never a direct kill); after ~10s pursuing one target it is banned from them for ~30s.
- [ ] Wrapped players cannot be shoved by the robot.
- [ ] With no valid target, enemies wander/patrol near their current position.
- [ ] Landing on an enemy from above stuns it ~10s and bounces the player.
- [ ] `./test.sh` passes, including new headless tests for targeting, bans, movement decisions, and wrap/stun timing.

## References

- `CONTEXT.md` — Kill zone, Lives pool, Ladder mode, Testability seam, Pushable glossary entries.
- `.scratch/enemies/DECISIONS.md` — grill Q&A and rationale.
- Prior planned features for structure precedent: `.scratch/pushable-props/`, `.scratch/ladder-alignment/`.
