# Decisions — Water Kill Zones, Shared Lives & Game Over

Grill session 2026-07-10 between Fabian and Claude. The feature started as "kill the player when they fall in the sandbox water" and grew into a lives/death/game-over system, because the codebase had **no existing death handling at all** (no health, no death FSM state, no game-over path).

### Q1: What does "killed" mean?
**Decision:** Shared pool of lives (default 2) + respawn at last safe ground + game over screen when a death occurs at 0 lives.
- **Why:** Cooperative kids' game; death should cost something but let play continue.
- **Implication:** This feature is really four systems: kill zones, lives pool + HUD, death/respawn presentation, game over screen.
- **Alternatives considered:** Instant level restart (too punishing mid-level); game-over-only (no continue mechanic).

### Q2: Where does the player respawn?
**Decision:** Last grounded position **with a stability margin** — the position is only recorded after the player has been continuously grounded for a short delay (~0.5 s), so we never respawn someone teetering on the last pixel of a ledge above water.
- **Why:** The naive "last grounded position" can be the ledge edge that caused the death.
- **Implication:** Needs a per-player tracker with a grounded timer; timer resets when airborne. Initial value is the spawn point.
- **Alternatives considered:** Exact last grounded position (rejected: edge-of-ledge deaths); hazard re-check at respawn point (deferred — accepted risk, see Q2b).

### Q2b: Respawning into danger
**Decision:** No hazard re-check at the respawn point for now. If a moving hazard occupies the spot, the player dies again — accepted.
- **Why:** Simplicity; current hazards are static water.

### Q3: Lives arithmetic
**Decision:** Lives start at 2; each death decrements; a death occurring **when lives are already 0** triggers game over. So **3 deaths total** before game over.
- **Why:** Explicitly confirmed with a walkthrough (2 → 1 → 0 → game over on next death).
- **Implication:** "Lives = 0" is a playable last-chance state, which drove the HUD question (Q10).

### Q4: Lives scope
**Decision:** Lives always reset to 2 on any level load — from the menu, from game-over restart, or on progressing to another level. No carry-over.
- **Why:** Simplest, and consistent with "restart as if selected from the menu".
- **Implication:** Default lives count lives in one place; no persistence layer needed.

### Q5: Multiplayer semantics
**Decision:** Only the killed player respawns, at *their own* last safe position; the other player is untouched. If lives are 0 and **either** player dies, it's game over for everyone.
- **Why:** Shared-pool cooperative design; the game already supports two simultaneous players (Fido = dog, Kitch = cat).

### Q6: Kill zone representation — object layer vs tile layer
**Decision:** Object layer with property-flagged rectangles, each object carrying a `deathType` string (e.g. `water`); tile-layer water stays purely visual. Property named around **kill/death**, not "water", so lava/spikes/pits reuse it.
- **Why:** (raised by Fabian) decouples the kill volume from the art — the player can sink into the water a bit, or the zone can extend to the map edge. Also mirrors the codebase's existing pattern exactly: ladders and collision are already object layers turned into volumes/entities at map load. Fewer, bigger rectangles than per-tile volumes.
- **Implication:** New map-loaded entity type (sensor volume with `isKillZone` + `deathType`), player-side overlap query like the ladder query. `deathType` is plumbed into the death state now, used for animation selection later.
- **Alternatives considered:** Tile-layer detection (rejected: couples gameplay to art, per-tile volumes); adding tile support later remains open.
- **ADR gate:** Not an ADR — easily reversible and unsurprising given the existing ladder/collision pattern.

### Q7: Heart icon
**Decision:** Red square placeholder drawn in code; texture/sprite applied later. No heart asset exists in the repo.

### Q8: Control during flash phases
**Decision:** During the death flash the player is locked in place, uncontrollable, and can't die again. During the spawn/respawn flash the player is **movable immediately** — the flash is purely visual feedback.
- **Why:** Flash must never feel like input lag.
- **Implication:** Death is a blocking FSM state; spawn flash is a decoration over normal control, and also plays on initial map load so players can locate their characters. A spawn *animation* may replace it later.

### Q9: Level state on respawn
**Decision:** Everything except the dead player's position and the lives count is untouched — coins, switches, keys, the other player.
- **Why:** Lets the players attempt to continue the game.

### Q10: HUD representation
**Decision:** A horizontal row of hearts (red squares) that disappear as lives are used — no numeral. Show the **raw lives counter** (2 hearts at start), so playing with zero hearts visible is the last-chance state.
- **Why:** Clearer for kids than icon+number.
- **Alternatives considered:** Showing lives+1 hearts ("attempts remaining", 3 hearts) so the screen is never empty while alive — offered as recommended, rejected by Fabian in favour of the raw counter.

## Key assumptions

- The sandbox map's water sits at the bottom of the level; one or two kill rectangles cover it. `sandbox.tmx` is edited as part of implementation (explicitly deferred from the planning session), not by hand-planning.
- Tiled edits re-export to `sandbox.lua` (the map loader consumes the Lua export; the tmx carries an export setting for this).
- ~0.5 s is the starting stability threshold and flash timings are tuned by feel during implementation — none are contractual.

## Trade-offs explicitly considered

- Object-layer kill zones trade per-tile precision for designer control and simplicity — accepted, precision wasn't wanted anyway.
- No respawn-point hazard re-check trades a possible death loop for simplicity — acceptable while hazards are static.
- Raw lives counter in the HUD trades "screen never empty" for arithmetic honesty — user's explicit call.

## CONTEXT.md entries added

- **Kill zone** — designer-placed invisible volume that kills a player on contact, tagged with a death type.
- **Death type** — string on a kill zone naming the kind of death (e.g. `water`), reserved for selecting death animations later.
- **Lives pool** — the shared, per-level count of deaths remaining before game over; not per-player.
- **Last safe position** — a player's most recent position after being stably grounded for a threshold time; where that player respawns.
