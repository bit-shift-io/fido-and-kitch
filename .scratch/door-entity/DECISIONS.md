# Decisions

### Q1: Latching

**Decision:** The door mirrors switch state both ways. No latch.
- **Why:** Keeps the door dumb; latching is a switch concern, not a door concern.
- **Implication:** A pressure switch only holds a door open while weighted. A lever (`switch.lua`) already latches by toggling, so the common "hit the switch, walk through" flow works unchanged.
- **Alternatives considered:** A `latching` property on the door, default true — rejected as state the door does not need. Latching on the pressure switch — deferred; nothing needs it yet.

### Q2: Footprint

**Decision:** Sprite box 3×3 tiles centred on the object; barrier collider 25% of a tile wide, full object height, blocking horizontally.
- **Why:** The wide sprite lets door art key into surrounding terrain; a thin barrier reads as a doorway rather than a wall.
- **Implication:** Derive both from the object's own width/height, never hard-coded pixels, so a tile-size change survives. 3× centred is symmetric, so no vertical lift is needed (the exit door lifts its sprite only because its box is 2×).
- **Alternatives considered:** Full object-rect collider — rejected, too wide to walk through cleanly. `walkable = true` so the closed door is a platform — rejected, an unlock would drop whoever stands on it.

### Q3: When solidity flips

**Decision:** `isDoorSolid(state) = state == 'closed'`. Passable the frame opening starts; solid only once the closing animation finishes.
- **Why:** Same rule as the drawbridge's `isDeckSolid(state) = state ~= 'closed'` — the permissive state wins through a transition. Permissive is solid for a bridge over a pit and passable for a door.
- **Implication:** Both transitions are forgiving. Nothing is sealed in or crushed by an animation frame.
- **Alternatives considered:** Solidity tracking the animation exactly — rejected, seals a player mid-doorway.

### Q4: Closing while occupied

**Decision:** A per-frame overlap query on the doorway defers a close while anything overlaps, and reverses an in-flight `closing` back to `opening`.
- **Why:** Q3 alone still lets a door close on an entity that never leaves. A switch must never be able to trap a player.
- **Implication:** State is recomputed fresh every frame from `(switchEnabled, occupied)` — no memory, no flags left behind, the property that made the drawbridge model safe. A door with a permanent occupant simply stays open.
- **Alternatives considered:** Close regardless and let the entity be pushed out — rejected, bump has no push-out and it would wedge geometry.

### Q5: Switch wiring

**Decision:** Unchanged. One switch, one `target`.
- **Why:** `switch.lua` and `pressure_switch.lua` both resolve a single object id; changing that touches every existing switchable.
- **Implication:** Two doors need two switches. Multi-target is its own feature.
- **Alternatives considered:** Comma-separated target ids; an EventBus channel property. Both rejected as scope beyond this feature.

### Q6: Rename scope

**Decision:** Assets and Tiled object names only. Method names stay.
- **Why:** `exitThroughDoor` / `exitInstant` read as verbs, and `ll1.tmx` calls them from executable `finish` property snippets — renaming risks a silent map break for no naming gain.
- **Implication:** `entity_door.png` → `entity_exit_door.png`, `exit.tx` → `exit_door.tx`, object `name="exit"` → `"exit_door"` across five maps, plus the level generator and its tests.

### Q7: Exit door sound

**Decision:** Copy `entity_drawbridge_open.wav` to `res/snd/entity_exit_door_open.wav`.
- **Why:** `exit_door.lua` has referenced that path all along with a comment noting the file never existed. A placeholder resolves it now and is the same copy-the-drawbridge move used for the new door.
- **Implication:** Delete the stale "no asset yet" comment. `tests/integration/exit_door_sound_test.lua` already asserts the `open` play and keeps passing.

### Q8: Golden test collision

**Decision:** Put the demo door in `sandbox.tmx` and extend `tmx_golden_test.lua`'s documented normalisation list, rather than hand-editing the golden exports.
- **Why:** The goldens are genuine Tiled exports; hand-adding an object or renaming a field inside one fabricates an export and destroys the differential test's whole value. The file already carries five documented staleness entries for exactly this situation (item 4 covers a map edited since capture).
- **Implication:** Slices 01 and 05 each add a normalisation entry explaining precisely which field is stale and why. Each entry must name the object, the field and the cause.
- **Alternatives considered:** Put the demo door in `fab1.tmx`, which no golden covers — sidesteps the problem entirely but hides the door in a work-in-progress level. Worth reconsidering if the normalisations get unwieldy.

### Q9: Existing asset collision

**Decision:** The rename slice lands first, on its own.
- **Why:** `res/img/entity_door.png` already exists and is the *exit* door's art. The new door cannot claim that filename until the exit door vacates it.
- **Implication:** Slice 01 blocks slice 02. Doing them in one slice risks the drawbridge copy silently overwriting live exit-door art.

## Assumptions

- Tiled `.tmx` sources are edited directly as XML; no Tiled round-trip is required to land a map change.
- `Sprite` exposes `playForward`, `playReverse` and `reverseFromCurrent`, as used by `drawbridge.lua`.
- `tests/support/headless_bootstrap.lua` can construct a real `Door` in the unit tier, as it does for `Drawbridge`.

## Trade-offs

- Copying drawbridge art means the door animates as a lowering deck until real art arrives. Accepted as a placeholder.
- Recomputing state every frame costs two `world:queryOverlap` calls per door per frame. Accepted; the drawbridge already pays this.

## CONTEXT.md entries added

- **Door** — switch-gated barrier blocking horizontal passage.
- **Exit door** — the level-completion entity, renamed uniformly.
- **Doorway** — the overlap volume a door consults before closing.

## ADR

None. The transition rule is a one-line function mirroring an existing entity, and reversing it costs nothing — it fails the "hard to reverse" condition. Logged in Q3/Q4 instead.

Note: `AGENTS.md` cites `docs/adr/0003` and `docs/adr/0005`, but `docs/adr/` does not exist in the working tree. Out of scope here; worth chasing separately.
