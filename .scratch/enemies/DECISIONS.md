# Decisions — Enemies (Spider & Robot)

Grill session 2026-07-15.

### Q1: Which player does an enemy target?
**Decision:** Nearest player, re-evaluated continuously (subject to bans/wraps).
- **Why:** Simple, readable threat in couch co-op; no per-placement config needed.
- **Implication:** Target can flip mid-chase as players cross; ban list filters candidates.
- **Alternatives:** locked-at-spawn, random, designer-set — rejected as less dynamic or more authoring burden.

### Q2: Spider behaviour after a wrap
**Decision:** Wrapped player is out of action for the full ~20s (no rescue); spider immediately retargets the other player.
- **Why:** Keeps both players engaged — one waits, one gets chased.
- **Implication:** The web is a pure timer; no interaction with it needed.
- **Alternatives:** teammate rescue, spider guards victim, post-wrap cooldown idle — rejected for scope/flow.

### Q3: Harassment ban (user-introduced mechanic)
**Decision:** After successfully harassing a player, an enemy is banned from targeting that player for ~30s. Spider: ban starts when the wrap lands. Robot: ban starts after it has been chasing the same player for ~10s (clock runs from target acquisition, not proximity or bump count).
- **Why:** Prevents perma-locking one player; forces attention rotation.
- **Implication:** Bans are per enemy-instance, per-player timers. Two spiders could wrap both players simultaneously — the ban only constrains the individual enemy.
- **Alternatives (robot trigger):** proximity-time accumulation, bump count — user chose chase-time for simplicity.

### Q4: No valid target
**Decision:** Wander/patrol near current position until a target becomes valid.
- **Why:** Level stays alive; predictable for players.
- **Alternatives:** stand still, return to spawn, chase-without-effect — rejected.

### Q5: Enemy physics
**Decision:** Player-like physics — gravity, solid vs. world geometry, can walk off edges. Ladders used to climb.
- **Why:** Reuses existing movement/collision model; enemies obey the same world rules players do.
- **Implication:** Enemies can strand themselves by falling; that's acceptable/emergent.
- **Alternatives:** edge-safe walking, floaty no-physics, per-enemy differences — rejected.

### Q6: Ladder selection
**Decision:** Opportunistic only — an enemy uses a ladder solely if it is already overlapping one while its target's Y differs; it climbs toward the target's Y. No searching or scoring of ladders.
- **Why:** Matches the user's "simply align axes" philosophy; zero pathfinding complexity.
- **Implication:** Enemies can get stuck below/above a player with no overlapping ladder; X-alignment keeps them pacing underneath — acceptable behaviour.
- **Alternatives:** nearest-useful ladder, ladder-nearest-target, greedy scan — rejected as planning.

### Q7: Robot push danger
**Decision:** Hazard-blind but gentle — the robot can push a player anywhere, but shoves are weak/slow enough the player can always out-run or jump away; danger arises only through player error.
- **Why:** Shared lives pool makes cheap enemy-caused deaths feel unfair; robot is a hindrance, not a killer.
- **Implication:** Shove strength is a tuning value; must be validated in play near ledges/kill zones.

### Q8: Wrapped player state
**Decision:** Frozen in place — input ignored, gravity settles them, world still affects them (kill zones can kill; robot shove explicitly cannot move them). Web sprite drawn over the player, fading out near expiry.
- **Why:** Simple, consistent with world rules; being wrapped over water etc. stays scary.
- **Alternatives:** invulnerable time-out, mash-to-escape, slow-not-freeze — rejected.

### Q9: Placement
**Decision:** Tiled objects (`spider`, `robot` types matching `src/entities/` filenames), any count per level, tuning via object properties.
- **Why:** Existing entity convention; difficulty by placement.

### Q10: Counterplay
**Decision:** Head-stomp stuns for ~10s with a player bounce; enemies are otherwise invincible.
- **Why:** Classic platformer feel, tactical co-op use (stun to create a window), without adding combat/death systems.
- **Implication:** Needs stomp detection (falling player overlapping enemy from above) despite enemies being non-solid to players. Stun does not trigger a harassment ban.

### Q11: Art
**Decision:** Placeholder coloured quads for spider, robot, and web; web fade is quad alpha.
- **Why:** Matches push box / boulder precedent; art comes later.

### Q12: Speed
**Decision:** ~70% of player walk speed (≈70 vs player 100).
- **Why:** Escapable in the open; threatening only in confined/vertical/distracted situations.

### Q13: Contact model
**Decision:** Enemies overlap players, never block them (sensor vs. players; solid vs. world). Spider wrap triggers on overlap; robot applies a steady sideways shove while overlapping. Head-stomp is a geometric check, not a physical landing.
- **Why:** Avoids physics fights between player controller and enemy bodies; keeps shove strength fully tunable.
- **Alternatives:** solid bodies, robot-solid-only — rejected.

## Assumptions

- Ban duration (30s), wrap duration (20s), robot chase-to-ban (10s), stun (10s), speed (70) are starting values, exposed as Tiled property overrides with code defaults (the established `windScale`-style pattern) — assumed, not explicitly confirmed.
- A just-freed player has no global immunity; only the wrapping spider's own 30s ban protects them (user's ban framing implies per-enemy scope).
- Enemies are not solid to each other and don't interact with each other.
- "Alive" targets only: dead/respawning players are not valid targets.

## Trade-offs

- Opportunistic ladder use means enemies are often simply *underneath* an elevated player — accepted for simplicity over pathfinding.
- Non-solid enemies mean the robot's "bump" is scripted displacement, not emergent physics — accepted for tunability and to avoid destabilising the player controller.

## CONTEXT.md entries added

Enemy, Harassment ban, Web wrap, Head stomp (see `CONTEXT.md` for definitions).
