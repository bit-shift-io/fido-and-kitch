# Ladder Alignment & Sliding

## Problem Statement

Ladders today are rigid: you press up or down to mount at whatever x you happen to be at, and once climbing you are frozen on a single vertical line — you cannot move sideways at all. This makes climbing feel stuck-on-rails, means a slightly-off approach looks misaligned with the ladder art, and makes two ladders placed side by side behave as two isolated columns with no way to move between them.

## Solution

Mounting a ladder now *aligns* the player to the ladder: when you press up/down near a ladder you slide horizontally onto its centre line, then climb. While on a ladder you can press left/right to drift sideways toward (and off) the edge; if you drift completely off every ladder you fall. Pressing up/down again re-centres you on the nearest ladder before resuming the climb. Because touching ladders hand off to each other, you can slide from one ladder onto an adjacent one and climb it — moving between two side-by-side ladders.

## User Stories

1. As a player, when I press up while standing off to the side of a ladder, I want my character to slide over onto the ladder and start climbing, so that I don't have to line up perfectly first.
2. As a player, when I press down at the top of a ladder while slightly off-centre, I want to slide onto it and descend, so that dismounting the top of a platform onto a ladder is forgiving.
3. As a player, the mount slide should feel like a normal walk-on (walk speed), so that stepping onto a ladder reads as a continuation of walking.
4. As a player climbing a ladder, I want to press left or right to shuffle sideways along it, so that I can reposition or set up to cross to a neighbouring ladder.
5. As a player, the sideways shuffle on a ladder should feel slower and more deliberate than walking, so that edging toward a drop feels careful.
6. As a player, if I shuffle so far sideways that I come completely off every ladder, I want to fall, so that the edge of a ladder is a real boundary.
7. As a player, if I shuffle sideways and then press up/down, I want to be re-centred on the nearest ladder and resume climbing, so that I can recover from an off-centre position without falling.
8. As a player standing between two ladders that touch, when I press up/down I want to commit to whichever ladder I'm mostly over, so that the choice matches where I'm standing.
9. As a player, I want to slide off one ladder onto a touching ladder and climb the second one, so that two side-by-side ladders let me move between them.
10. As a player holding a vertical key and then pressing a horizontal key (or vice-versa) while on a ladder, I want the key I pressed most recently to take over, so that switching between climbing and shuffling feels responsive rather than locked.
11. As a player, I want the climb animation to keep playing whenever I'm moving on the ladder — sideways or vertically — so that any movement reads as active climbing, and holding still shows a static climb pose.
12. As a player, when the mount slide or a re-centre completes, I want to end up exactly on the ladder's centre line, so that the sprite lines up cleanly with the ladder art with no jitter.

## Implementation Decisions

- The whole feature is a rework of the existing `LadderState` (behavioural FSM state in `src/player/player_states.lua`). No new top-level FSM states are added; instead `LadderState` gains an internal **mode**:
  - `aligning` — moving horizontally toward a target ladder's centre-x; no vertical motion.
  - `climbing` — centred; up/down move vertically at the existing climb speed.
  - `sliding` — a horizontal key is held; drift sideways at the slow slide speed.
- `LadderState` stays kinematic with gravity off (as today). Movement remains velocity-driven via `collider:setLinearVelocity`; the exact-centre finish snaps x with a direct position set to avoid overshoot jitter.
- **Axis arbitration is last-pressed-wins.** The state tracks which axis (vertical vs horizontal) was most recently newly-pressed, using rising-edge detection per axis — the same edge-tracking pattern already used for the `use` action in `WalkIdleState`. On release of the active axis, control falls back to the other axis if it is still held.
- **Target-ladder selection** when aligning: the ladder whose centre-x is nearest the player's current centre-x, chosen from all ladders the player currently overlaps.
- **Mount** (entering `LadderState` from the ground) starts in `aligning` at **walk speed** (`player.speed`, 100).
- **On-ladder horizontal** (sliding to an edge, and re-aligning after a slide) uses a **slow** speed — a new tunable, ~60.
- **Fall-off** condition: the player collider no longer overlaps *any* ladder (reuse of the existing overlap query). On that condition, transition to `FallState`.
- Vertical climb speed is unchanged (100).

## Testing Decisions

- Good tests target **external movement decisions**, not FSM internals: given an input (keys held/pressed, player x, set of ladder rects), what horizontal/vertical velocity or target does the ladder logic produce, and which mode/transition results.
- Extract the pure decision logic into a testable seam alongside the existing `src/player/player_movement.lua` (which already isolates `decideHorizontalMovement` as a pure function). Candidate pure functions: nearest-ladder-centre selection, "am I centred within one step" test, last-pressed axis resolution, and fall-off detection given overlap results.
- These run as **fast gameplay regression tests** (headless Lua), consistent with existing prior art in the repo's test suite. No graphical LÖVE launch.
- Prior art: existing tests for `player_movement` and the pushable decision logic.
- File naming/location follow the project's existing Lua test convention (co-located fast regression tests).

## Out of Scope

- Diagonal movement on a ladder (moving up and sideways at once).
- Climbing over the top of a ladder onto a platform, or any change to how you leave a ladder at its top/bottom (unchanged from today).
- Ladders wider than one tile, or non-rectangular ladders.
- Special handling for a real gap between ladders (only touching/overlapping ladders hand off; a gap is just "off the ladder → fall").
- Tuning the exact slow-slide value beyond a sensible default.
- Any change to climb speed, jump, or ground movement.

## Acceptance Criteria

- [ ] Pressing up/down while overlapping a ladder off-centre slides the player to that ladder's centre at walk speed, then begins climbing.
- [ ] Once centred, up/down climbs vertically at the current climb speed.
- [ ] Holding left/right on a ladder moves the player sideways at the slow slide speed with the climb animation playing.
- [ ] The player falls (enters FallState) exactly when the collider fully clears every ladder.
- [ ] After sliding off-centre, pressing up/down re-centres on the nearest overlapping ladder, then climbs.
- [ ] Two touching ladders can be crossed: slide off one onto the other and climb the second.
- [ ] When both a vertical and horizontal key are held, the most recently pressed axis controls movement; releasing it falls back to the still-held axis.
- [ ] Alignment and re-centre finish exactly on centre-x with no visible jitter.

## References

- Reworks `LadderState` in `src/player/player_states.lua`.
- Ladder geometry: `src/entities/ladder.lua`, `src/utils/rect.lua` (`centre()`).
- Overlap queries and per-frame edge tracking: `src/player/player.lua` (`queryLadder`, `isDown`, `useDown` pattern).
- Prior-art pure decision seam: `src/player/player_movement.lua`.
- Glossary: CONTEXT.md — "Ladder mount alignment", "Ladder slide", "Ladder mode".
- Rationale: DECISIONS.md.
