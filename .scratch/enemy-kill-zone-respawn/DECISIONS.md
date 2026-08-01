### Q1: Which enemies are affected?
**Decision:** Both Spider and Robot.
- **Why:** No reason to special-case one; both are NPC-based and can plausibly be shoved/walk
  into a kill zone.
- **Implication:** Shared logic goes on the common `NPC` base rather than per-entity.
- **Alternatives considered:** Robot only (spiders climb/wrap and might not reach a kill
  zone) — rejected, spiders can still walk on the ground and fall like anything else.

### Q2: Solidity/interactivity during death and respawn flashes
**Decision:** Mirror the player exactly — non-solid/kinematic collider and locked FSM during
the death flash (blocking, gated by `onComplete`); non-blocking flash on respawn (entity is
immediately active again), same as `Player:startSpawnFlash`.
- **Why:** This is already the established pattern for the player; no reason to invent a
  different one for enemies.
- **Implication:** Reuse the same shared sequence/constants rather than a bespoke enemy
  timing.

### Q3: Behavior state carry-over on respawn
**Decision:** Full reset — no stun, chase target, or wander bans survive respawn.
- **Why:** User wants a respawned enemy to behave as if the level just loaded, not to
  instantly resume chasing the player that just killed it.
- **Implication:** `NPC:respawn()` must explicitly clear stun/target/ban state, not just
  reset position and FSM state name.

### Q4: Spider wrap interrupt on death
**Decision:** Wrap is released immediately when the spider dies, not when it respawns.
- **Why:** Leaving a player stuck on a dead spider's wrap timer would feel broken/unfair.
- **Implication:** `Spider` needs to track which player it wrapped (`wrappedTarget`), since
  today nothing on the spider references its wrap target — only the player-side `WrappedState`
  knows it's wrapped. Death must force that player's FSM back to `WalkIdleState`.
- **Alternatives considered:** Let the wrap persist until spider respawn — rejected as
  unnecessarily punishing to the player.

### Q5: Systemic effects (score/UI/lives)
**Decision:** None — purely visual/behavioral, scoped to the enemy's own sprite/collider/FSM.
- **Why:** Confirmed with user; no scoring or enemy-count system exists in this game.
- **Implication:** No `EventBus` event needs to reach `InGameState` for enemy death (unlike
  player death, which emits `player_died` for lives-pool handling).

### Q6: Bird entity scope
**Decision:** Out of scope — kill zones only need to detect NPC-based enemies (Spider, Robot).
- **Why:** `bird.lua` has no FSM, no chase behavior, and isn't built on the shared `NPC` base
  this feature extends; it doesn't practically fly into ground-level kill zones either.
- **Implication:** No changes to `bird.lua`.

### Q7: Enemy death sound
**Decision:** Reuse the existing kill-zone `deathType` sound hook (same code path as the
player), even though the underlying sound assets are currently missing/silent.
- **Why:** Keeps behavior consistent and future-proof — when sound assets land, enemies get
  them for free.
- **Implication:** No new sound asset or separate hook for enemy death.

### Q8: Facing direction on respawn
**Decision:** Reset to the original spawn-time facing, captured once at `NPC:init`.
- **Why:** Robot's shove behavior depends on facing; a respawned Robot should behave
  consistently with how the level was authored, not an arbitrary default.
- **Implication:** `NPC:init` must capture facing (not just `homeX`/`homeY`) at construction
  time, alongside position.

### Q9: Payoff for killing an enemy
**Decision:** A fixed 30-second delay between the death flash-out completing and the enemy
respawning — the reward is a stretch of level free of that enemy.
- **Why:** User feedback mid-planning: killing an enemy needs to feel like it's worth
  something beyond a cosmetic flash; a brief window without that enemy in play is the payoff.
- **Implication:** `DeadState` can't respawn immediately on flash completion like the original
  plan assumed — it needs a dt-accumulated timer (same pattern as existing stun/ban timers in
  `npc_brain.lua`) gating the respawn call. Not configurable per enemy or kill zone; one
  shared constant for this feature.

## Key assumptions
- Kill zones remain instant-death/binary for enemies, exactly as they are for players — no
  damage/HP concept is being introduced.
- The existing `Flash` component and `Tween` usage are generic enough to reuse as-is; only the
  orchestration around them (which today lives inline in `Player`/`DeadState`) needs
  extracting into shared logic.
- `PlayerSensors.queryKillZone(world, collider)` has no player-specific logic in its body and
  can be called with an NPC's collider without modification.

## Trade-offs considered
- Considered giving enemies a `SafePosition`-style rolling respawn point (mirroring the
  player) instead of a fixed original spawn — rejected per the original feature request,
  which explicitly asks for "original spawn location," and because enemies don't have a
  meaningful "last safe ground" concept the way players do (their whole existence is
  ground-based patrol/chase).

## CONTEXT.md updates
See `CONTEXT.md` (project root) — the **Kill zone** entry now notes it kills enemies too, the
**Enemy** entry's boundary line is corrected (kill zones are a real exception to "cannot be
destroyed"), and a new **Enemy death and respawn** entry documents the flash/fade/30s-delay
sequence.
