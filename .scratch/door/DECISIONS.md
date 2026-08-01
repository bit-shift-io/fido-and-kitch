# Door Entity — Decisions

### Q1: How does the door respond to being triggered — toggle, one-shot, or live state tracking?
**Decision:** The door tracks the switch's live state directly: `:switch(switch, user)` reads `switch.state` ('on'/'off') and opens or closes to match, rather than toggling independently each time it's called.
- **Why:** A lever switch flicks the door open, and flicking it again closes it. A pressure switch should behave identically through the same call — momentary presence should open the door only while pressed (closing again on release), and a latching plate should open it once and leave it open, exactly mirroring the plate's own latching semantics rather than the door reimplementing them.
- **Implication:** The door needs no independent toggle state of its own, and by construction supports several switches each independently pointing their `target` at the same door — the door just reacts to whichever `:switch()` call arrives last.
- **Alternatives considered:** An independent toggle counter on the door (flip on every `:switch()` call regardless of the caller's state) — rejected because it would desync from a pressure switch's release/latching behaviour (the door would stay "toggled open" after a momentary plate released).

### Q2: Should opening/closing be an instant frame swap or an animated transition?
**Decision:** Animated, using the same reversible-timeline model as `drawbridge` (`playForward`/`playReverse`/`reverseFromCurrent`), including reversing an in-flight animation in place if the requested direction flips mid-transition.
- **Why:** User confirmed "it works the same as the drawbridge for the animation."
- **Implication:** Reuses `src/components/timeline.lua` and the existing `Sprite:reverseFromCurrent`/`playForward`/`playReverse` API with no new animation infrastructure.

### Q3: Should the closed-door collider be exactly 1 tile tall, given the codebase's documented AABB gotcha?
**Decision:** No — the door's blocking collider follows `Map:createStaticPhysicsBodyBoundary`'s pattern of extending past the exact bounds of what it's guarding, rather than sitting flush with the walking surface's top edge.
- **Why:** AGENTS.md documents that a solid collider flush with the ground's top edge does not reliably block horizontal movement under bump's AABB resolution, and explicitly calls out "a locked door" as the motivating example — cross-referencing the user's initial "1 tile height" answer against this surfaced the conflict before it became a bug.
- **Implication:** The door's collider height is derived the same way `createStaticPhysicsBodyBoundary` derives its boundary walls' overlap — taller than the single tile it occupies, not clamped to it.

### Q4: How wide should the blocking collider be?
**Decision:** Roughly 1/4 of the tile's width, widened to 1/2 if a quarter proves unreliable.
- **Why:** User's initial instinct, and consistent with the drawbridge's own trigger collider (`self.triggerWidth = self.rect.width * 0.25`) — width doesn't need to span the full tile since any solid rectangle in the path fully blocks horizontal movement under bump's collision resolution; only height (relative to the walking surface) matters for reliably blocking.
- **Implication:** No change needed if 1/4 works during implementation/testing; bump to 1/2 only if a narrower column proves to let something clip through.

### Q5: Does the door block pushable props, or only the player?
**Decision:** Blocks pushables the same as the player — a plain wall-like solid collider, not player-only.
- **Why:** User confirmed directly ("doors should block pushables").
- **Implication:** No entity-type filtering needed on the collider's solidity — unlike the drawbridge's deck (walkable ground for anyone) or the pressure switch's plate (a sensor that only *reads* who's on it), the door's collider is unconditionally solid or unconditionally passable based on its own state, full stop.

### Q6: When exactly does the door stop/start blocking relative to its animation?
**Decision:** The door remains solid through the entire `'closing'` transition and only becomes passable once `'open'` is reached (animation fully finished) — not the instant `'opening'` begins. Conversely, starting to close blocks immediately, the instant the `'closing'` state begins.
- **Why:** User: "the door allows players through once the open animation completes, and as soon as it starts closing it blocks." This is the inverse of the drawbridge's `isDeckSolid` (solid whenever *not* `'closed'`) — the door is solid whenever *not* `'open'`.
- **Implication:** `Door.isDoorSolid(state)` is `state ~= 'open'`, mirroring but inverting `Drawbridge._internal.isDeckSolid`. No per-frame occupancy polling is needed (unlike drawbridge/pressure_switch) since the door's state changes are driven entirely by external `:switch()` calls, not by proximity detection of its own.

### Q7: Editor representation — real art or a placeholder rectangle?
**Decision:** A `gid`-based Tiled object (bottom-anchored, 1 tile), reusing the existing `entity_door.png` tile already declared in `res/tilesets/props.tsx` (tile id 5 / gid 6).
- **Why:** User: "it would be nice to see something in the editor if we can." Investigation found the art and tileset entry already exist — currently referenced only by the `exit_door` template (`exit.tx`) — and nothing prevents a second object `type` from referencing the same tileset tile for its editor icon, since Tiled's preview art is independent of which entity class `entity_factory.lua` constructs (driven by the object's `type` attribute).
- **Implication:** No new art asset or tileset entry needed. Editor preview for `door` will look identical to `exit_door`'s preview — acceptable since no distinct door art exists yet; revisit if that visual overlap proves confusing to level designers in practice.

### Q8: Default state on map load.
**Decision:** Always starts `'closed'`. No per-instance override property.
- **Why:** User: "default to closed." A door with nothing wired to it should still gate its passage rather than silently doing nothing (an unwired door defaulting open would be indistinguishable from no door at all).
- **Implication:** Simpler entity — no `startOpen`/`startState` property to parse or test.

### Q9: Sandbox map integration — where does the new door go, and what does it replace?
**Decision:** Re-point the existing switch's (`object id 44`) `target` from the exit door (`object id 43`, inherited from the `switch.tx` template default) to a newly placed `door` object positioned near the switch. Exact placement is a demo choice, not real level design — anywhere that visibly blocks a short passage near the switch is sufficient.
- **Why:** User: "just place it somewhere near the switch for a demo." The switch's wiring is currently a no-op in sandbox (`exit_door` has no `:switch()` handler), so this both fixes that dead wiring and demonstrates the new entity.
- **Implication:** Only `sandbox.tmx` changes (new object + one property override); the exit door's own template and behaviour are untouched.

## Key Assumptions

- The door has no `Usable` component of its own — per the original ask
  ("a door is simply a player block which requires something to trigger it"),
  it is only ever opened via an external `:switch()` call, never directly by
  a player pressing use.
- No sound assets exist yet for door open/close; referenced wav paths will
  warn-and-skip via `Sound:play`, matching the `pressure_switch` precedent
  exactly (`res/snd/entity_pressure_press.wav` etc. don't exist either).

## Trade-offs Considered

- **ADR needed?** No. Nothing here fails the three-condition gate: the
  design closely follows three existing, well-established patterns
  (drawbridge's animation/sprite-bleed, pressure_switch/ladder's
  `target`+`:switch()` wiring, and `createStaticPhysicsBodyBoundary`'s
  collider-extension pattern) rather than introducing a new one. Logged
  here instead.

## CONTEXT.md Updates

New glossary entry added (see `CONTEXT.md`):

- **Door** — a player- and pushable-blocking obstacle, closed by default,
  opened/closed by an external `target` + `:switch()` caller (a lever switch
  or pressure switch). Authored as a 1×1 tile in the editor; renders as a 3×3
  sprite box in-game (drawbridge-style bleed). Solid whenever not fully
  open; the reverse of the drawbridge's own solidity rule.
