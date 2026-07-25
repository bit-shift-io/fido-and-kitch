# Drawbridge — Decisions

### Q1: Default (unactivated) behaviour
**Decision:** The drawbridge starts **closed** and is impassable until triggered.
- **Why:** The whole point is a one-way gate — a crossing that doesn't exist until a correct-side player commits to it.
- **Implication:** The bridge needs an explicit closed state that blocks passage, not just a directional filter on an always-present floor.
- **Alternatives considered:** "Always open one-way, gated only the other way" — rejected; the user wants the crossing genuinely absent until opened.

### Q2: Who can trigger open
**Decision:** Eligibility is configurable via a Tiled property; **default players only**, with an opt-in to also allow enemies.
- **Why:** Designers may want enemy-openable bridges for harder puzzles, but the safe default is player-controlled.
- **Implication:** Eligibility gates *opening* only. Once open, the deck is solid to everyone regardless of eligibility.
- **Alternatives considered:** Hard-coded players-only (less flexible); any-entity (removes the one-way tension by default).

### Q3: What "impassable" looks like + how the correct side is configured
**Decision:** The drawbridge sits over a **real gap/chasm** the designer authors. Closed = the gap is exposed. The **correct side is a Tiled custom property** that also mirrors the sprite and animation.
- **Why:** Keeps the hazard authored explicitly in terrain (reuses existing gap/kill-zone tooling) and keeps facing designer-controlled and unambiguous.
- **Implication:** The close animation can be the **open animation played in reverse**, so the Sprite component needs reversible playback. One art asset, mirrored, serves all four orientations (two facings × open/close).
- **Alternatives considered:** Inferring the correct side from adjacent solid tiles — rejected as too implicit and easy to get wrong; a solid-invisible-wall-only model with no real gap — rejected, the user wants a genuine chasm underneath.

### Q4: What a *blocked* entity experiences when closed
**Decision:** Blocked entities (wrong side, or ineligible) are **stopped like a wall** — they bump the closed bridge and cannot step onto the tile; they do not fall into the gap by bumping it.
- **Why:** Falling on every failed crossing would be punishing and unreadable; a wall is predictable.
- **Implication:** Closed state needs a solid **closed barrier** collider that blocks horizontal entry, separate from the walkable deck. The gap below is still real — the barrier just prevents an entity from wandering into it off a closed bridge.
- **Alternatives considered:** Letting blocked entities fall — rejected as too punishing for a routing primitive.

### Q5: Interrupting the open↔close transition
**Decision:** A close-in-progress that gets re-triggered **reverses in place** back to open.
- **Why:** A near-miss (last entity leaves, another immediately arrives) should feel smooth, not locked-out.
- **Implication:** Requires reversing the animation timeline mid-playback and keeping solidity coherent across the reversal. Drove the decision to build a full bidirectional Timeline API.
- **Alternatives considered:** "Must finish first" (simpler state machine, brief lockout) — rejected for feel.

### Q6: Trigger geometry
**Decision:** A **sensor zone on the correct side** detects the approaching eligible entity; the entity's own collider overlapping that sensor is the trigger. (User: "the collider serves this purpose already.")
- **Why:** Reuses the existing sensor/overlap collision path (as `ladder`, `switch`, `jump_pad` do). The sensor sits ahead of the bridge on the correct side so the deck lowers *before* the entity reaches the gap.
- **Implication:** Trigger sensor position/size mirrors with the `facing` property.
- **Alternatives considered:** Edge-of-tile contact (needs a thin solid edge to stand against) and overlap+fall-catch (snap-on-top) — both fussier than a lead-in sensor.

### Q7: What keeps the bridge open
**Decision:** Any entity (player **or** enemy) whose collider **overlaps the bridge tile** keeps it open. Close begins when the last one clears the footprint.
- **Why:** Lets enemies follow a player across behind them, and guarantees the bridge never closes on an occupant.
- **Implication:** Occupancy is a per-frame world-query decision over the bridge tile; it's the natural place for a testable helper.
- **Alternatives considered:** "Standing on top only" — rejected; passing-through entities should also hold it open, and top-only detection is fussier.

### Q8: Reset scope
**Decision:** **Reset to closed on level restart**, matching pushable props. Not tied to individual player death/respawn (occupancy governs state naturally).
- **Why:** Consistency with the established prop-reset model; a single death shouldn't reshape the level.
- **Alternatives considered:** Pure per-frame recompute with no snapshot — effectively equivalent here since state is occupancy-derived, but an explicit spawn-state reset matches the project pattern and is clearer.

### Q9: Reversible-animation API scope
**Decision:** Build a **full bidirectional playback API** on Timeline/Sprite (play forward, play reverse, reverse mid-playback, dual-end finish signal, queryable direction/speed), not just the minimum the drawbridge needs.
- **Why:** Timeline already carries most of the primitives (`isReverse`, `reverse()`, `resetReverse()`, `speed`, signed `progress`); hardening them into a real API with tests pays off for future entities.
- **Implication:** Slightly more surface to test now; less rework later. The drawbridge is the first consumer and its integration test doubles as the API's real-world check.
- **Alternatives considered:** Minimal reverse-only support — rejected in favour of a reusable API.

## Key assumptions

- The pit/gap and any kill zone under the bridge are authored separately in Tiled; the drawbridge entity does not generate terrain or hazards.
- The open-animation art asset is produced via the art pipeline (`raw/docs/art_asset_prompt_guide.md`); placeholder art is acceptable until then.
- Enemies use collider overlap the same way players do, so occupancy and (opted-in) eligibility can treat them uniformly.

## CONTEXT.md additions

- **Drawbridge** — the one-way tile entity (see glossary entry).
- **Reversible timeline** — the bidirectional playback capability added to `Timeline`/`Sprite` (see glossary entry).
