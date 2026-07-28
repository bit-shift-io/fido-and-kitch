### Q1: Entity type name in Tiled
**Decision:** Use `type = "story"` in Tiled object properties
- **Why:** Matches filename `src/entities/story.lua` per project convention (entity type maps to filename)
- **Implication:** No `Map.typeIgnores` entry needed; entity auto-loads
- **Alternatives considered:** `sign`, `narrative`, `dialogue` — rejected to match file naming convention

### Q2: Text property format
**Decision:** String property `text` with `\n` for line breaks
- **Why:** Simple, matches Tiled's string property handling; Lua string escaping handles `\n` naturally
- **Implication:** No special parsing needed; `text:gsub("\\n", "\n")` at load time
- **Alternatives considered:** Multiline Tiled text property (not well-supported), JSON array of lines (overcomplicated)

### Q3: Trigger mechanism
**Decision:** Overlap (sensor collider) + use key press (Right Shift / Q)
- **Why:** Consistent with existing player interaction patterns (Pickup, Usable components)
- **Implication:** Entity needs a `Collider` component set as sensor; player use key already wired in `Player`
- **Alternatives considered:** Automatic on overlap (too intrusive), dedicated "talk" key (new input binding)

### Q4: Speech bubble visual
**Decision:** Simple rendered bubble above entity using camera world-to-screen, no external asset
- **Why:** No new art assets needed; consistent with minimalist art style; easy to position
- **Implication:** Draw in entity's `draw()` using `love.graphics` primitives + `love.graphics.printf` for text wrapping
- **Alternatives considered:** Pre-made bubble image (asset dependency), Slab UI (overkill, not world-space)

### Q5: Bubble dismissal
**Decision:** Auto-dismiss when player no longer overlaps entity collider
- **Why:** Matches "walk up, read, walk away" flow; no extra key press needed
- **Implication:** Check overlap in `update()`; hide bubble when overlap ends
- **Alternatives considered:** Press use key again to close (extra action), timeout after N seconds (arbitrary)

### Q6: Cooldown duration
**Decision:** ~0.5 seconds (30 frames at 60fps)
- **Why:** Short enough to feel responsive, long enough to prevent double-trigger on key hold
- **Implication:** Timer in entity state; reset on dismiss
- **Alternatives considered:** 1 second (too long), frame-perfect (too sensitive)

### Q7: Player control during bubble
**Decision:** Full movement retained
- **Why:** Co-op game; freezing one player blocks the other; narrative should not interrupt flow
- **Implication:** No state machine takeover; bubble is passive overlay
- **Alternatives considered:** Freeze player (breaks co-op), disable jump only (inconsistent)

### Q8: Multiplayer interaction
**Decision:** Independent per-player triggering
- **Why:** Both players may want to read; co-op design pillar
- **Implication:** Entity tracks trigger state per player (by player index or entity reference)
- **Alternatives considered:** Single trigger for both (one player blocks other), first-come-first-served

### Q9: Physics collider type
**Decision:** Static sensor collider (non-walkable)
- **Why:** Overlap detection only; not a platform or wall; `walkable = false`
- **Implication:** Added via `Collider` component; added to world as sensor
- **Alternatives considered:** Dynamic (unnecessary), solid static), walkable platform (blocks movement)

### Q10: State machine vs inline logic
**Decision:** Inline logic in entity `update()` (simple two-state: idle/showing)
- **Why:** Only two states; no complex transitions; avoids StateMachine overhead
- **Implication:** Direct `self.showing` boolean + `self.cooldown` timer
- **Alternatives considered:** StateMachine component (overengineered for 2 states)

---

## Key Assumptions
- Tiled maps already export `.lua` via STI; `type="story"` objects load automatically
- Player use key handling exists in `Player`/`PlayerState` (Right Shift / Q / gamepad button 1)
- Camera exposes `worldToScreen(x, y)` for bubble screen positioning
- `Entity:queueRemove()` / `queueDestroy()` pattern not needed (entity persists)

## Trade-offs Explicitly Considered
| Decision | Trade-off Accepted |
|----------|-------------------|
| Inline state logic | Slightly less extensible if dialogue complexity grows later |
| No typewriter effect | Simpler implementation; instant readability |
| Sensor collider only | Cannot stand on entity; purely narrative |
| Auto-dismiss on walk-away | Player might walk away mid-read (accepted as minor UX cost) |

---

## CONTEXT.md Updates (New Terms)

### story entity
**Definition:** A map entity of Tiled type `story` that displays a speech bubble with custom text when a player overlaps it and presses the use key.
**Boundary:** Purely narrative; no gameplay effects, no branching, no flags. Not a pickup, not a usable item, not a platform.

### speech bubble
**Definition:** A world-space UI element rendered above an entity, showing wrapped text, that follows the entity on screen and dismisses when the triggering player leaves the entity's trigger volume.
**Boundary:** Not a HUD element; not a Slab UI component; rendered via `love.graphics` in entity's `draw()`.

### narrative trigger
**Definition:** The combination of player overlap + use key press that activates a story entity's speech bubble.
**Boundary:** Distinct from `Pickup` (auto-collect) and `Usable` (held item interaction) components.
