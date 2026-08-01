# Handoff: Enemy Kill Zone Death & Respawn

## Summary

Kill zones currently only kill players. This feature extends them to also kill NPC-based
enemies (Spider, Robot): an enemy that touches a kill zone plays the same flash-and-fade death
sequence a player does, stays fully gone for a fixed 30-second window (the player's payoff for
the kill), then respawns at its original Tiled spawn position and facing with the same
flash-and-fade-in a player respawn uses, resuming default wander behavior with no stale
stun/target/ban state.

The death/respawn flash-and-fade sequence is shared code between `Player` and `NPC` rather
than duplicated — it's currently inlined across `Player:die`, `player_states.DeadState`, and
`Player:startSpawnFlash`, and gets extracted into a small shared module both entity types call.

## Implementation order

1. **`01-robot-kill-zone-death-respawn.md`** — do this first. It contains all the foundational
   work (flash/fade extraction, NPC origin capture, kill-zone polling for NPCs, the shared
   `DeadState` with its 30s delay, full state reset on respawn) plus the Robot-specific
   end-to-end behavior. This is the bigger of the two slices.
2. **`02-spider-kill-zone-death-respawn-wrap-release.md`** — blocked by (1). Reuses everything
   from the Robot slice and adds the one Spider-specific piece: tracking `wrappedTarget` and
   force-releasing a wrapped player the instant the Spider dies.

## Links

- [PRD](PRD.md)
- [DECISIONS](DECISIONS.md)
- No ADRs — none of the decisions here met the three-condition gate (this extends an existing,
  already-established pattern rather than introducing a new hard-to-reverse architecture).

## Gotchas / implementer notes

- **Don't re-derive the flash timing.** Reuse the existing constants (0.15s interval, 8
  blinks, ~1.2s total) from `player_states.lua` — there's no separate tuning for enemies.
- **The 30-second delay is a plain `dt` timer**, not a `Tween` — it gates the *respawn* call,
  which happens *after* the ~1.2s flash-fade-out has already completed via its own
  `onComplete`. Don't conflate the two durations.
- **`queryKillZone` is already collider-generic** (`src/player/player_sensors.lua`) — check
  whether it's simplest to call it as-is from `NPC:update`, or lift it out of the
  `PlayerSensors` module first so neither side owns a "player-only" function it isn't. Either
  way, don't fork a second copy of the query logic.
- **Full reset means full reset.** Respawn must explicitly clear stun timers, current chase
  target, and harassment bans — resetting only position and FSM state name will leave stale
  targeting state that immediately re-triggers a chase.
- **Spider's wrap release needs a new reference.** `Spider` doesn't currently store who it
  wrapped (`wrapOverlappingTarget` calls `entity:wrap()` and forgets it) — this has to be
  added before death can release it.
- **Verify the extraction is behavior-preserving.** Since issue 01 refactors `Player`'s
  existing death/respawn code path, the existing player death/respawn tests are the safety
  net — they should pass unmodified after the extraction. If they need changes to pass, that's
  a signal the extraction changed player behavior, not just its location.
- **CONTEXT.md is already updated** (Kill zone, Enemy, and a new Enemy death and respawn entry)
  — no glossary work needed as part of implementation, just keep behavior consistent with what
  those entries describe.
