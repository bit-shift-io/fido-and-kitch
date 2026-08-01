# Enemy Kill Zone Death & Respawn

## Problem Statement

Kill zones currently only detect and kill players. Enemies (Spider, Robot) can walk or be
shoved into the same water/pit/spikes/lava volumes and simply sit there, ignoring them —
which looks broken and lets players "cheese" enemies out of the way permanently rather than
seeing them reset.

## Solution

Kill zones also detect NPC-based enemies (Spider, Robot). An enemy that touches a kill zone
dies using the same visual/behavioral sequence as a player death: it locks its current
behavior, flashes (blinking visibility) while fading out over ~1.2s, then becomes
non-interactive. Rather than respawning immediately, the enemy then stays gone for a fixed
30-second window — the player's reward for the kill is a stretch of level free of that
enemy. After the window elapses, it respawns at its original Tiled spawn location (position
and facing), flashing back in the same way a player does on spawn/respawn, and resumes its
default behavior (wander) from a fully-reset state.

The death/respawn flash-and-fade sequence is extracted into logic shared between the player
and enemies, rather than duplicated, since the visual behavior is identical.

## User Stories

1. As a player, I want enemies that fall into hazards to die and respawn, so that the world
   feels consistent (hazards are lethal to everyone, not just me).
2. As a player, I want a killed enemy to visibly flash and fade out the same way I do when I
   die, so that the feedback language is consistent across the game.
3. As a player, I want a respawning enemy to flash and fade back in the same way I do, so
   that its return reads clearly as "was dead, now alive again" rather than "just appeared."
4. As a player, I want a respawned enemy to come back at its original spawn point and facing
   direction, so that levels play out consistently each time an enemy dies.
5. As a player, I want a respawned enemy to forget whatever it was doing before it died
   (chase target, stun, wander bans), so that it doesn't immediately resume chasing me the
   instant it reappears.
6. As a player, I want a meaningful stretch of time free of a killed enemy before it comes
   back, so that killing it feels like a genuine payoff rather than a cosmetic blip.
7. As a player, I want a spider that dies while it has wrapped me to release me immediately,
   so that I'm not stuck waiting on a corpse's wrap timer.
8. As a player, I want a stunned (stomped) enemy that then falls into a kill zone to still
   die normally, so that kill zones remain universally lethal regardless of enemy state.
9. As a developer, I want the death/respawn flash-and-fade sequence shared between `Player`
   and enemies, so that future changes to the "die and respawn" feel only need to happen in
   one place.

## Implementation Decisions

- **Shared death/respawn flash helper.** Extract the flash+fade sequence currently inlined
  across `Player:die`, `player_states.DeadState`, and `Player:startSpawnFlash` into a shared
  helper (used by both `Player` and `NPC`). It exposes two entry points equivalent to the
  player's current behavior:
  - a death sequence: locks the entity's behavior FSM, sets alpha to 1, tweens alpha to 0
    over `blinks * interval` seconds, attaches a `Flash` toggling `visible` for the same
    duration, and calls a completion callback once the flash finishes (used to gate
    transitioning to "fully dead"/respawn).
  - a spawn/respawn sequence: sets alpha to 0, tweens alpha to 1, attaches a non-blocking
    `Flash` (no completion gating — the entity is playable/active immediately), matching
    `Player:startSpawnFlash`.
  - Same constants as today (0.15s interval, 8 blinks, ~1.2s total) reused for enemies —
    no separate tuning knob for enemy vs. player timing.
- **NPC death state.** Add a `DeadState` to `npc_states.lua` mirroring
  `player_states.DeadState`: on enter, stop movement, make the collider non-solid/kinematic
  (no gravity), reuse the shared death sequence. Once the flash-out completes, the enemy does
  **not** respawn immediately — see "Respawn delay" below. There is no lives pool / game-over
  interaction for enemies; no event needs to reach `InGameState`.
- **Respawn delay.** After the death flash/fade-out finishes, the enemy stays fully gone
  (invisible, non-solid, FSM parked) for a fixed 30-second window before respawning — the
  player's payoff for killing it. Implemented as a timer inside `DeadState` (or a following
  state), tracked with plain `dt` accumulation like other timers in this codebase (e.g. stun
  bans in `npc_brain.lua`), not a `Tween`. Not configurable per enemy/kill-zone/level for this
  feature — one shared constant.
- **NPC origin capture.** `NPC:init` currently only stores `homeX` (used by `WanderState`
  range-checks). Extend this to capture the full origin needed for respawn: `homeX`, `homeY`,
  and initial facing direction, captured once at `NPC:init` time from the Tiled object,
  analogous to how `Player:init` seeds `SafePosition`.
- **NPC:die(deathType) / NPC:respawn().** Mirrors `Player:die`/`Player:respawn`: `die` is
  idempotent (no-op if already dead), transitions the FSM to `DeadState`. `respawn` teleports
  the collider to the captured origin, restores initial facing, resets the FSM to the
  enemy's default state (`WanderState`), clears stun/target/ban state (a full reset — same
  as if the level had just loaded), and starts the shared spawn/respawn flash sequence.
- **Kill zone detection for enemies.** `PlayerSensors.queryKillZone(world, collider)` already
  takes a plain collider and has no player-specific logic. Reuse it directly for enemies
  (call from a shared location both `Player` and `NPC` can reach, or expose it as a
  standalone function rather than a `PlayerSensors`-only method) instead of writing a
  parallel `NPCSensors` copy. Each `NPC:update`, when not already dead, queries for an
  overlapping kill zone the same way `Player:update` does, and calls `self:die(zone.deathType)`
  on a hit.
- **Death sound.** Reuse the same kill-zone `deathType` sound hook the player uses (currently
  silent since the underlying sound assets aren't wired yet, but the code path is identical —
  no separate enemy death sound asset).
- **Stunned enemies remain killable.** A kill zone check runs regardless of `StunnedState` —
  being stunned does not grant immunity to hazards.
- **Spider wrap release on death.** `Spider` does not currently track which player it has
  wrapped. Add a `self.wrappedTarget` reference, set when `wrapOverlappingTarget` succeeds,
  cleared on wrap expiry. When a `Spider` dies (enters `DeadState`), if `wrappedTarget` is
  still wrapped, force that player's FSM back to `WalkIdleState` immediately (bypassing the
  web's own expiry timer) so the wrap ends the instant the spider's death sequence begins,
  not when the spider respawns.
- **Bird is out of scope.** `bird.lua` is not an `NPC`, has no behavior FSM, and isn't part of
  this feature — kill zones do not need to detect it.
- **No systemic effects.** Enemy death/respawn does not touch the lives pool, score, HUD, or
  camera framing targets — it is scoped entirely to the enemy's own sprite, collider, and FSM.

## Testing Decisions

- Cover the shared death/respawn flash sequence once (unit-level, headless), then rely on
  that coverage for both `Player` and `NPC` call sites rather than re-testing flash/fade
  timing per entity type.
- Unit-test `NPC:die`/`NPC:respawn` state transitions, origin capture (homeX/homeY/facing),
  and full state reset (stun/target/ban cleared) headlessly — no map/physics needed for pure
  state-transition assertions, following the pattern in `tests/unit/kill_zone_test.lua`.
- Integration-test (real map, real kill zone, real collider queries) that an enemy walking or
  being pushed into a kill zone actually triggers death, and that it reappears at its original
  position after the sequence completes — mirroring `tests/integration/kill_zone_sound_test.lua`
  structure but for an NPC actor instead of a player.
- Integration-test the Spider wrap-release case specifically: wrap a player, kill the spider,
  assert the player's `wrapped` flag clears and FSM returns to `WalkIdleState` without waiting
  for the web's expiry.
- File naming/location: `.unit.test.lua` / `.integration.test.lua` (this project uses `.lua`
  throughout, not `.test.ts`/`.test.js` conventions), co-located under the nearest
  `tests/unit/` or `tests/integration/` directory per existing convention (not per-module
  `__tests__/`, which this codebase does not use — see `tests/README.md`).

## Out of Scope

- Any lives pool, score, HUD, or camera-framing interaction for enemy death.
- A separate/distinct enemy death sound asset (reuses the existing, currently-silent hook).
- `bird.lua` or any non-NPC entity.
- Retaining any pre-death state on respawn (chase target, stun, wander bans, position other
  than origin) — always a full reset.
- Tuning enemy flash/fade timing separately from the player's existing constants.
- New kill-zone types, death-type-specific enemy behavior, or damage/HP systems (kill zones
  remain instant-death only, as they are for players).

## File Structure (if relevant)

No new top-level directories. Expected touch points:
- New shared module for the death/respawn flash sequence (location decided during
  implementation — likely alongside `src/components/flash.lua` or as a small function set
  `Player` and `NPC` both require).
- `src/player/player.lua`, `src/player/player_states.lua` — refactored to call the shared
  sequence instead of inlining it (behavior unchanged).
- `src/npc/npc.lua` — origin capture (homeX/homeY/facing), `die`/`respawn` methods, kill zone
  polling in `update`.
- `src/npc/npc_states.lua` — new `DeadState`.
- `src/entities/spider.lua` — wrapped-target tracking and release-on-death.
- `src/player/player_sensors.lua` (or a new shared sensor location) — kill zone query reuse.

## Acceptance Criteria

- [ ] A Robot that enters a kill zone plays the death flash/fade-out, becomes non-solid, and
      is no longer chasing/shoving while dead.
- [ ] The Robot stays gone for 30 seconds after the death flash-out completes, then respawns
      at its original Tiled spawn position and facing, flashing/fading back in the same way a
      player respawn does.
- [ ] A Spider that enters a kill zone dies and respawns the same way.
- [ ] A Spider that dies while it has a player wrapped releases that player immediately (not
      waiting for wrap expiry or spider respawn).
- [ ] A respawned enemy starts in its default wander behavior with no stun, target, or ban
      state carried over.
- [ ] A stunned enemy that touches a kill zone still dies.
- [ ] The flash/fade sequence code is shared (not duplicated) between `Player` and `NPC`.
- [ ] No change to player death/respawn behavior, lives pool, score, or camera framing.

## References

- `src/components/flash.lua` — existing shared `Flash` component.
- `src/player/player.lua`, `src/player/player_states.lua` — existing player death/respawn
  sequence this feature mirrors.
- `src/player/safe_position.lua` — prior art for "capture a position at the right moment" on
  the player side (not reused directly — enemies respawn at their original spawn, not a
  rolling last-safe-position).
- `src/npc/npc.lua`, `src/npc/npc_states.lua`, `src/npc/npc_brain.lua` — existing enemy FSM
  structure this feature extends.
- `src/entities/kill_zone.lua`, `src/player/player_sensors.lua` — existing kill zone entity
  and detection query.
- `.scratch/enemies/PRD.md` — original enemies feature, which explicitly scoped enemy
  death/respawn out.
- `CONTEXT.md` (project root) — glossary entries for Kill zone / Enemy / Enemy death and
  respawn, updated by this feature.
