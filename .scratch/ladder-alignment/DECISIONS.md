# Ladder Alignment & Sliding — Decisions

### Q1: Mount alignment — snap vs animated slide
**Decision:** Animated horizontal slide to the ladder centre, then climbing begins.
- **Why:** A visible slide reads as "stepping onto the ladder" and matches the platformer feel; an instant snap looks like teleporting.
- **Implication:** `LadderState` needs an `aligning` mode that runs before vertical climbing; vertical input is held until centred.
- **Alternatives considered:** Instant snap to centre — rejected as jarring.

### Q2: Fall-off vs adjacent-ladder catch
**Decision:** Overlap-any-ladder. You stay on a ladder as long as your body overlaps *some* ladder; touching ladders catch you automatically as you cross into them. Fall only when no ladder is under you.
- **Why:** Simplest model that naturally supports moving between side-by-side ladders without special-casing.
- **Implication:** No explicit gap detection; "touching" ladders just work because the overlap is continuous. A real gap is simply "off all ladders → fall".
- **Alternatives considered:** Explicit gap check treating touching ladders as one wide surface — rejected as more code for the same observable behaviour.

### Q3: Exact fall-off threshold
**Decision:** Fall only once the player collider is *fully* clear of every ladder (no overlap at all).
- **Why:** Forgiving; lets the player edge a body-width past a ladder edge before losing grip, which feels better than dropping the instant the centre crosses.
- **Implication:** Reuse the existing overlap query (`queryLadder`-style bounds overlap) as the "still on a ladder?" test; when it returns nothing, transition to FallState.
- **Alternatives considered:** Centre-leaves-all-ladders — rejected as too twitchy near edges.

### Q4: Input priority when a vertical and horizontal key are both held
**Decision:** Last-pressed axis wins.
- **Why:** Most fluid — the player can be climbing, tap left to shuffle, release, and resume climbing, without a fixed axis dominating.
- **Implication:** Needs rising-edge detection per axis (which axis was *newly* pressed most recently), plus fallback to the still-held axis on release. Follows the existing `useDown` edge-tracking pattern.
- **Alternatives considered:** Vertical-always-wins / horizontal-always-wins — simpler (pure poll, no edge state) but feel locked; rejected.

### Q5: Which ladder to centre on when straddling two touching ladders
**Decision:** Nearest centre — align to whichever ladder's centre-x is closest to the player's current centre-x.
- **Why:** Matches where the player is mostly standing; predictable from position alone.
- **Implication:** On align, gather all overlapping ladders and pick min |ladderCentreX − playerCentreX|.
- **Alternatives considered:** Direction-of-last-slide — rewards intent but needs extra state and can feel like it "jumps past" where you're standing; rejected.

### Q6: Horizontal movement speed
**Decision:** Two speeds.
- **Initial mount align** (first entry onto the ladder from the ground): **walk speed** (`player.speed`, 100).
- **On-ladder horizontal** (sliding toward an edge, and re-aligning after a slide): **slow** (~60, new tunable).
- **Why:** Stepping onto a ladder should read as a continuation of walking (fast). Once on the ladder, sideways movement is a careful shuffle, so edging toward a drop or crossing to a neighbour feels deliberate.
- **Implication:** The `aligning` mode must know whether this alignment is the initial mount (walk speed) or an on-ladder re-align (slow speed). Add a slow-slide tunable on the player.
- **Alternatives considered:** Single slow speed for everything (original answer) — corrected by the user: initial mount should be walk speed. Reusing `climbSpeed` for the slow value considered; a dedicated slide tunable keeps climb and slide independent.

### Q7: Animation during horizontal movement on a ladder
**Decision:** Climb sprite, actively animating during any ladder movement (horizontal or vertical). Static climb pose when not moving.
- **Why:** Simplest and consistent — "moving on the ladder = climbing animation". Avoids needing a sideways-shuffle animation that doesn't exist.
- **Implication:** Animation `playing` flag is driven by "is the player moving at all this frame", not specifically vertical movement (today it's vertical-only).
- **Alternatives considered:** Frozen climb pose while horizontal / walk animation while horizontal — rejected; more branching for no clear benefit, and walk-on-a-ladder looks odd.

## Key assumptions
- "Centred" is tested with a tolerance of about one slide-step so the align finishes cleanly and snaps exactly to centre-x rather than oscillating around it.
- Vertical climb speed stays 100 (unchanged).
- `LadderState` remains kinematic with gravity off throughout aligning/sliding/climbing; the player only starts falling when they leave all ladders.
- Ladders are one tile (32px) wide, positioned by top-left, centre-x via `Rect:centre()` — as they are today.

## ADR gate check
Considered an ADR for the ladder mode model / last-pressed arbitration. **Skipped** — it is a localised rework of a single FSM state, cheaply reversible, and not surprising in a way a future reader couldn't get from this file. Logged here instead. (Contrast: ADR 0001 covers the pushable snap model, which is cross-cutting and hard to reverse.)

## New CONTEXT.md terms
- **Ladder mount alignment** — the horizontal slide onto a ladder's centre before climbing.
- **Ladder slide** — holding left/right to shuffle sideways along/off a ladder.
- **Ladder mode** — the internal aligning/climbing/sliding sub-state of `LadderState`.
