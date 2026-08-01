# NPC Follow System — Decisions

### Q1: Bird navigation — A* vs raycast+steer
**Decision:** Raycast + steering (boids-style)
- **Why:** Simpler, no grid/pathfinding infrastructure needed; bird ignores collision so A* overkill; easy to tweak feel
- **Implication:** Bird may get stuck in concave geometry; can upgrade to A* later if needed
- **Alternatives considered:** Full A* on navigation mesh — rejected: no navmesh exists, adds complexity for v1

### Q2: Rabbit ladder/puzzle navigation — path following vs sensors
**Decision:** Follow player's recorded position breadcrumbs (path history)
- **Why:** Most reliable for ladders/puzzles; player already navigates them correctly; avoids duplicating sensor logic
- **Implication:** Rabbit lags slightly behind player (by breadcrumb interval); needs position history buffer on player
- **Alternatives considered:** 
  - Reuse player sensor queries (`queryLadder`, `queryLadderBelow`) — rejected: NPCs don't have physics bodies for sensor queries
  - Simplified A* — rejected: same infrastructure gap as bird

### Q3: Player switching logic
**Decision:** 
- Bird: Random switch when both players within `switchRange` (e.g., 8 tiles), checked every `switchInterval` (e.g., 3s)
- Rabbit: Switch to nearest player when both within `switchRange` (e.g., 6 tiles), evaluated every frame
- **Why:** Bird feels playful/unpredictable; rabbit feels loyal but shared; both simple to implement
- **Implication:** Rabbit may "jitter" between players at boundary; add hysteresis (stick to current until other is significantly closer)

### Q4: Cage spawn type configuration
**Decision:** Tiled custom property `spawn_type` on cage object (string: "bird" | "rabbit", default "bird")
- **Why:** Matches existing pattern (cage already has properties); no schema changes; map maker workflow unchanged
- **Implication:** Typo in property = silent default to bird; could add validation in entity factory
- **Alternatives considered:** Separate cage entity types (`cage_bird`, `cage_rabbit`) — rejected: bloats entity factory, less flexible

### Q5: "All cages unlocked" → exit door enabling
**Decision:** Event bus: cage emits `cage_unlocked` with count; `InGameState` tracks total, emits `all_cages_unlocked`; exit door listens
- **Why:** Decouples cage from exit door; uses new event bus; single source of truth in game state
- **Implication:** Exit door must exist in level; if no exit door, event fires but nothing happens (safe)
- **Alternatives considered:** Direct cage→door reference — rejected: tight coupling, hard to test

### Q6: NPC teleport/blink behavior
**Decision:** 
- Trigger: NPC distance to target player > `teleportDistance` (20 tiles) OR player respawns (safe position update)
- Effect: NPC position = player position + small offset; visual "blink" (alpha 0→1 over 0.2s)
- **Why:** Simple, reliable, no pathfinding recovery needed; visual feedback prevents confusion
- **Implication:** Bird may teleport mid-flight (looks odd); could add "feather poof" particle later
- **Alternatives considered:** Pathfind back — rejected: complex, unnecessary for visual-only NPCs

### Q7: NPC physics/collision
**Decision:** Sensor-only collider (`collider.isSensor = true`), no `walkable` flag, no collision response
- **Why:** Purely visual; matches "don't collide with pets" requirement; simplest physics setup
- **Implication:** NPCs pass through walls, each other, players, enemies; no physical interaction possible
- **Alternatives considered:** No collider at all — rejected: may need collider for spatial queries (e.g., "NPCs near player")

### Q8: Player position history for rabbit breadcrumbs
**Decision:** Add `positionHistory` buffer to `Player` component (circular buffer, max 120 entries = 2 seconds at 60Hz)
- **Why:** Rabbit reads from this; minimal intrusion on player; timestamped positions allow time-based interpolation
- **Implication:** Player now has NPC-specific state; acceptable since co-op already has 2 players
- **Alternatives considered:** Global position history manager — rejected: over-engineering for single consumer

### Q9: Bird steering behavior details
**Decision:** Simple seek + separation:
- `desiredVelocity = (targetPos - birdPos):normalized() * maxSpeed`
- `steering = desiredVelocity - velocity`
- Add separation from other birds (if multiple): `separation = sum((birdPos - otherPos):normalized() / distance)`
- Clamp velocity, apply per frame
- **Why:** Boids-lite; no cohesion/alignment needed for single bird per cage; performant
- **Implication:** Bird oscillates near target; add arrival radius (slow down within 2 tiles)

### Q10: Rabbit hop movement
**Decision:** Simplified physics — horizontal move toward target breadcrumb, jump when:
- Next breadcrumb is higher (ladder/step up)
- Gap detected (raycast down finds no ground)
- Use player's jump velocity scaled down (e.g., 0.7x)
- **Why:** Reuses player jump feel; simpler than full movement FSM
- **Implication:** May not handle complex puzzle timing; acceptable for visual follower

### Q11: Exit door integration
**Decision:** Exit door has `usable = false` initially; listens for `all_cages_unlocked` → sets `usable = true`; visual feedback (glow, open animation)
- **Why:** Clear state machine; matches existing door patterns
- **Implication:** Level must have exit door entity; if missing, level uncompletable (level design responsibility)

### Updated CONTEXT.md Entries
- **NPC (Non-Player Character):** A visual-only companion entity that follows players. Two types: Bird (flies, ignores collision) and Rabbit (hops, follows path breadcrumbs). No gameplay interaction.
- **Cage Spawn Type:** Tiled property `spawn_type` on cage objects determining which NPC spawns ("bird" | "rabbit").
- **Breadcrumb Trail:** Timestamped position history recorded by Player, used by Rabbit NPC for reliable ladder/puzzle navigation.
- **All Cages Unlocked Event:** Event bus signal emitted when last cage in level is unlocked, enabling the exit door.