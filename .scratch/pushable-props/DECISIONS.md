# Decisions — Pushable Props

Rationale from the grill session, so the "why" survives.

### Q1: Architecture — entity or component?
**Decision:** Separate entities per prop type (`push_box`, `boulder`, `pressure_switch`), with shared behaviour in a reusable `Pushable` component. Build via composition.
- **Why:** Matches the codebase's existing entity-as-component-bag pattern; separate Tiled `type`s keep the template palette clean and drag-placeable.
- **Alternatives considered:** One `type` with a `mode` property to switch box vs boulder — rejected; the user wants distinct placeable entities and composition for shared bits.

### Q2: Scope of the feature
**Decision:** Build all three now — push box, boulder, and pressure switch — because they "all work together."
- **Why:** The switch is the payoff for the pushing mechanic; shipping the box alone leaves the puzzle loop incomplete.
- **Implication:** Larger feature, but the three share the support/snap and target-drive machinery.

### Q3: Push movement feel
**Decision:** Continuous slide at the player's walk speed while pushed; the box moves only while the player is actively holding a direction into it and is grounded. Boulder is a momentum variant (below).
- **Why:** "Slide" language + fits the existing velocity-based physics (a dynamic collider with the right x-velocity).
- **Alternatives considered:** Grid-locked Sokoban shove — rejected; the user wants free continuous positioning with alignment only on forcing events.

### Q4: Terminology — "switch" vs "pressure switch"
**Decision:** Keep them as distinct glossary terms. Existing `switch` = a **user-triggered lever** (player "uses" it via `Usable`). New **pressure switch** = weight-activated (something resting on the tile); deactivates when the weight is removed. The pressure switch reuses the lever's `target` + `:switch()` drive.
- **Why:** An entity named `switch` already exists (`src/entities/switch.lua`); conflating them would be confusing. Surfaced during the grill by reading the existing code.

### Q5: What blocks pushing ("nothing on top")
**Decision:** Another pushable resting on top hard-blocks pushing the one below. A player standing on top blocks pushing **by default**, with a per-prop opt-in flag (`allowPushWhenStoodOn`) to allow it (a co-op "one player rides while another pushes" mechanic).
- **Why:** Predictable stacking; the opt-in leaves room for deliberate co-op puzzles without making it the default footgun.
- **Implication:** Props are standable surfaces and can rest on each other.

### Q6: Support / fall / snap model
**Decision:** Support is decided by the solid ground under the prop's **centre-x**. Over solid → rests at whatever x it was left at (no forced alignment). Once the centre passes over an unsupported tile → snap x to that tile's centre (± small tolerance) and fall straight down. Un-pushable while airborne; pushable again on landing. A filled hole is solid ground the player walks across.
- **Why:** Gives tile-perfect hole-filling puzzles without free-body teetering, while keeping continuous positioning everywhere else. See ADR 0001.
- **Alternatives considered:** Pure physics (fall when >50% off a ledge, no snap) — rejected; wouldn't reliably align to fill a one-tile hole. Full grid-lock — rejected; too rigid for the desired feel.

### Q7: Alignment is NOT the resting default
**Decision:** Props do **not** live tile-aligned. Snapping happens only on the two forcing events: (a) falling into a hole, (b) coming to rest on a pressure switch. The player can push a prop back out of a snapped position.
- **Why:** Correction from an earlier wrong assumption on my part; the user wants free positioning with alignment as an event, not a constant.

### Q8: Water
**Decision:** No buoyancy, no floats/sinks flag. A prop that falls into water keeps falling (crossing the cosmetic water tiles and the kill-zone sensor without dying) until it hits the bottom map border, and rests there.
- **Why:** The original request had a floats/sinks flag, but the user chose to defer all buoyancy. Water today is purely cosmetic tiles + a `kill_zone` sensor (`deathType="water"`); sensors are crossed by props, so no special handling is needed for the sink case.
- **Implication:** Dropped the level-editor float flag from scope. Buoyancy is a future feature.

### Q9: Boulder movement
**Decision:** Same initiation as a box (player walks into it), but it keeps rolling on its own after contact ends. Rolls at player walk speed. Stops when it falls (snaps like a box), hits a wall, hits another pushable, or hits a player. No damage. Pushable again once stopped, if there's room, including back the other way.
- **Why:** Simple, predictable momentum puzzle piece; reuses the box's fall/snap and walk-speed values.
- **Alternatives considered:** A distinct harder "shove" launch / faster roll speed — rejected for now; keep it at walk speed.

### Q10: Reset semantics
**Decision:** Level restart resets everything (all prop positions + switch states) to spawn. Player death/respawn resets only the player — props are untouched.
- **Why:** Clean puzzle start on restart; but a single death shouldn't rewind the whole board the player has been arranging.
- **Implication:** Props need a spawn-state snapshot captured at load and re-applied on restart only.

### Q11: Pressure switch details
**Decision:** Single-tile (32×32) sensor plate. "Substantially on it" = weight's centre-x within a small tolerance of the plate tile's centre while overlapping. Activated while ≥1 qualifying weight (player or pushable) is on; deactivates when the last leaves. Momentary (default): drive `target:switch()` on both activation and deactivation. Latching: drive once on first activation, never on release. Drives the target through the same mechanism as the lever `switch`.
- **Why:** Reuses the alignment-tolerance idea already used for hole snapping; reuses the proven target-drive path.

### Q12: Snap-to-plate timing
**Decision:** The box snaps to the plate tile centre only when the player **stops pushing** (on release), not mid-push.
- **Why:** Snapping mid-push would fight the player's input. Releasing then settling onto the plate feels natural and still lets the player shove the box back off.
- **Origin:** User's own suggestion during the grill.

### Q13: Push constraints
**Decision:** Player must be grounded to push. Horizontal pushing only (no lifting or pushing down). The push requires the player to be actively moving and holding a direction into the prop.
- **Why:** Pushing is a walking action; keeps mid-air collisions as simple blocks.

### Q14: Rendering
**Decision:** Placeholder filled quads via `love.graphics.rectangle`. Distinguish by colour: box brown, boulder grey, pressure switch a flat plate that changes colour when active. All props 32×32 (one tile). (Colours/sizes are dealer's-choice defaults, easily changed.)
- **Why:** "Just use a quad as placeholder" per the request; real art is out of scope.

## Assumptions
- The project uses Tiled `.tmx` → exported `.lua` maps; new props are authored as objects with a `type` matching `src/entities/<type>.lua`, and custom properties read via `object.properties.*`. (Confirmed against `src/map.lua`, `src/entities/kill_zone.lua`, `res/map/sandbox.lua`.)
- A dynamic collider with zero horizontal velocity already falls straight down via the existing `Collider:worldUpdate`/`Motion` gravity path — reused rather than reimplemented. (Confirmed against `src/physics/bump/collider.lua`, `motion.lua`.)
- Map-generated static colliders have no `.entity`, which is how ground/support probes distinguish solid map ground from entities — reused for the support-under-centre-x check. (Confirmed against `src/player/player.lua:295`, `ground_support.lua`.)
- There is an existing level-restart path to hook prop reset into; the exact entry point must be located during implementation (see HANDOFF gotchas).

## CONTEXT.md additions
New glossary terms added: **Pushable**, **Push box**, **Boulder**, **Pressure switch**, **Snap alignment**. Definitions live in `CONTEXT.md`.
