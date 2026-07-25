# Drawbridge (One-Way Tile)

## Problem Statement

Every path through a level is currently symmetric: if a player can walk left-to-right over a spot, anything can walk right-to-left over it too. Designers have no way to build a route that opens up *only after* a player commits to it from a particular side — a one-way passage that a second player or a chasing enemy can then follow through, but could never have opened themselves. There's no primitive for "one player unlocks this crossing for everyone else."

## Solution

Introduce the **drawbridge**: a single-tile, one-way crossing placed over a real gap in the terrain.

- It starts **closed** — the gap is fully exposed, a real hazard like any other pit. Approaching from the wrong side means falling in, not bumping a wall. (Revised after hands-on playtesting — see Q4 in DECISIONS.md; the original design had a closed barrier blocking both sides like a wall.)
- When an **eligible** entity (a player by default) approaches from the drawbridge's **correct side**, the bridge plays its **open (lower) animation** and becomes solid, walkable ground spanning the gap.
- While open, the crossing is solid to *everyone* — the second player, and even enemies — so they can follow the player who opened it across, from either direction.
- The bridge stays open as long as any entity overlaps its tile. When the last one clears, it plays the **close (raise) animation** — the open animation played in reverse — and returns to blocking the gap.
- If an eligible entity re-triggers it mid-close, the animation **reverses in place** back to open.

This gives designers a directional gate: the correct-side player is the only one who can open the route, but once open it's a shared crossing.

## User Stories

1. As a player, I want to walk toward a closed drawbridge from its correct side and have it lower into a solid crossing before I reach the gap, so that I can walk straight across without falling.
2. As a player approaching from the wrong side, I want the closed bridge to stay shut and never open for me, so that the crossing is genuinely one-way until someone opens it from the correct side.
3. As a player approaching from the wrong side, I want the exposed gap to be a real hazard (I fall in, like any other pit) rather than a wall I bump into, so the one-way gate has real stakes and doesn't feel like an arbitrary invisible block. (Revised from the original "blocks like a wall" design after playtesting — see DECISIONS.md Q4.)
4. As the second player, I want to cross a drawbridge that my co-op partner opened, from either direction, so that one player can unlock a route for the other.
5. As a player, I want an enemy chasing me to be able to follow me across a bridge I opened, so that opening a crossing carries a real trade-off.
6. As a player, I want the bridge to stay open the whole time anyone is standing on or overlapping it, so that it never closes under me or a partner mid-crossing.
7. As a player, I want the bridge to close (raise) once the last entity has left it, so that it resets itself to a one-way gate for the next approach.
8. As a player, I want a bridge that's just started closing to re-open smoothly if I step back onto its trigger, so that a near-miss doesn't feel janky.
9. As a designer, I want to place a drawbridge from the Tiled template palette and set which side is the "correct" (opening) side with a property, so that authoring is drag-and-drop.
10. As a designer, I want the drawbridge sprite and its trigger to mirror automatically to match the correct-side property, so that one art asset serves both facings.
11. As a designer, I want to restrict *who* can open a drawbridge (players only by default, with the option to allow enemies too), so that I can tune puzzle difficulty.
12. As a designer, I want the close animation to just be the open animation played in reverse, so that I only author one animation.
13. As a designer, I want every drawbridge to reset to closed on level restart, so that puzzles start clean.
14. As a developer, I want the Sprite/Timeline component to support reversible playback (play forward, play reverse, reverse mid-playback), so that the drawbridge and future entities can drive an animation in both directions from one asset.

## Implementation Decisions

- **New entity** `drawbridge` (`Class{__includes = Entity}`, one Tiled `type`), built by composition from existing components (`Sprite`, `Collider`) plus a small internal state machine for closed / opening / open / closing.
- **Placement over a real gap.** The designer authors an actual 1-tile gap in the terrain and drops the drawbridge onto it. The pit below is ordinary terrain (or a kill zone) authored independently — the drawbridge does not create the hazard, it gates the crossing.
- **Collision:**
  - A **deck collider** — static, solid (non-sensor) — that represents the walkable, lowered bridge. Present only while the bridge is open/opening/closing; absent while closed, at which point the gap is fully exposed (no barrier — see DECISIONS.md Q4).
  - A **trigger sensor** on the correct-approach side, always present, that detects eligible entities and starts the open transition.
- **Correct side** is a Tiled custom property (e.g. `facing` = `left` / `right`) naming the side the bridge lowers toward and the side its trigger sensor sits on. The sprite mirrors to match (horizontal flip via the existing `Sprite:setFacing`).
- **Eligibility** is a Tiled custom property controlling who may open the bridge — players only by default, with an opt-in to also allow enemies. Eligibility gates *opening* only; once open, the deck is solid to all entities regardless of eligibility.
- **Occupancy → close.** The bridge stays open while ≥1 entity's collider overlaps the bridge tile (players and enemies both count). When the last overlapping entity leaves, the close transition begins.
- **Reversible animation.** The close animation is the open animation played in reverse. Solidity is coherent across opening/open/closing (deck solid throughout) so an entity is never dropped mid-transition (occupancy keeps it open while anyone is present); only the fully-`closed` state has an exposed gap. A mid-close re-trigger reverses the timeline in place back toward open.
- **Reset** — the drawbridge resets to closed spawn state on level restart, matching the pushable-props reset model. An individual player's death/respawn does not force it closed (occupancy governs that naturally).

## Reversible Sprite/Timeline API

The `Timeline` component already carries the primitives for this (`isReverse`, `reverse()`, `resetReverse()`, `speed`, signed `progress`); this feature hardens them into a deliberate public API on `Sprite`/`Timeline` and covers them with tests:

- Play an animation forward from the start.
- Play an animation in reverse from the end.
- Reverse direction from the current frame mid-playback (the drawbridge's interrupt case).
- A finish signal that fires at the forward end *and* at the reverse end, so the entity knows when open/close has completed.
- Direction and speed are queryable/settable so other entities (and ping-pong loops) can reuse the API later.

## Testing Decisions

- Good tests assert **external decisions and geometry**, not internal wiring — mirroring the pushable-props and ground-support test style. Follow the project's headless "fast gameplay regression test" pattern (`tests/*_test.lua` registered in `tests/run.lua`), not a LÖVE launch.
- Extract pure decision helpers so they're testable without the full runtime:
  - **Eligibility + trigger:** given an entity type and the bridge's facing/eligibility config, should this overlap start an open?
  - **Occupancy:** given the set of colliders overlapping the bridge tile, should the bridge be open or begin closing?
  - **State transitions:** closed → opening → open → closing → closed, including the mid-close reverse-in-place back to open.
  - **Solidity mapping:** for a given state, is the deck solid and is the closed barrier present?
- **Reversible Timeline** gets direct unit tests: forward-to-end fires finish; reverse-to-start fires finish; reverse mid-playback flips direction and lands on the expected frame; frame index is correct at both ends.
- An **integration test** (per the project's integration-test convention) on a small fixture map: an eligible player approaches from the correct side and crosses; a player approaching from the wrong side is blocked; a second entity crosses while the first holds it open; the bridge closes after the last leaves.
- Modules exercised: the drawbridge state/decision helpers, the reversible Timeline API, and the drawbridge integration on a fixture map.

## Out of Scope

- **Multi-tile / wide bridges.** Single tile only; a long drawbridge is a later extension.
- **Sound effects and final art.** Placeholder or first-pass art only; the animation asset is authored elsewhere (`raw/docs/art_asset_prompt_guide.md`).
- **Bridges that gate anything other than the shared crossing.** No `target`/`:switch()` driving of remote entities — this is a local crossing, not a switch.
- **Config beyond Tiled.** Placement and tuning are Tiled template + custom properties only; no in-repo editor UI.
- **Player-facing "who opened it" bookkeeping.** Eligibility gates opening; the bridge does not remember or attribute which player opened it.
- **Vertical / ceiling drawbridges.** Horizontal crossing over a gap only.
- **Ping-pong looping animations.** The reversible API is built to allow it, but no shipped entity uses ping-pong in this feature.

## File Structure

```
src/
  entities/
    drawbridge.lua        # new: drawbridge entity + state machine
  components/
    sprite.lua            # modified: reversible playback API surface
    timeline.lua          # modified: harden/expose reverse + dual-end finish
res/
  templates/
    drawbridge.tx         # new: Tiled template (facing, eligibility properties)
  map/
    <fixture>.tmx/.lua    # new: integration-test fixture map
tests/
  drawbridge_test.lua     # new: state/decision + solidity helpers
  timeline_reverse_test.lua # new: reversible playback
  run.lua                 # modified: register new tests
```

## Acceptance Criteria

- [ ] A closed drawbridge has no barrier; the gap is fully exposed and a real hazard from either side until opened. (Revised — see DECISIONS.md Q4.)
- [ ] An eligible entity (player by default) approaching from the correct side triggers the open (lower) animation and the crossing becomes solid before the entity reaches the gap.
- [ ] An entity approaching from the wrong side cannot open the bridge, and falls into the gap rather than being blocked.
- [ ] An ineligible entity (e.g. an enemy when not opted in) cannot open the bridge from either side.
- [ ] Once open, the deck is solid ground to all entities from either direction; a second player and an enemy can both cross.
- [ ] The bridge stays open while any entity overlaps its tile and never drops an occupant.
- [ ] After the last entity leaves, the bridge plays the close (raise) animation and returns to closed.
- [ ] Re-triggering during the close animation reverses it in place back to open with no visual snap.
- [ ] The drawbridge's facing (correct side) is set by a Tiled property and mirrors both the sprite and the trigger side.
- [ ] Eligibility (players only vs players + enemies) is set by a Tiled property, defaulting to players only.
- [ ] The drawbridge resets to closed on level restart.
- [ ] `Sprite`/`Timeline` expose reversible playback (forward, reverse, mid-playback reverse) with a finish signal at both ends, covered by tests.

## References

- `.scratch/pushable-props/` — prior art for a Tiled-placed, component-composed prop with a reset-on-restart model and headless decision-helper tests.
- `src/components/timeline.lua`, `src/components/sprite.lua` — existing (partial) reverse primitives this feature hardens.
- `src/entities/ladder.lua`, `src/entities/jump_pad.lua` — patterns for a sensor-based, Tiled-placed entity with sprites.
- `src/player/ground_support.lua`, `tests/ground_support_test.lua` — the world-query + decision-helper + headless-test pattern to follow.
- `AGENTS.md` — entity/component/state-machine conventions; new map entity = new `src/entities/<type>.lua` matching a Tiled object `type`.
- `raw/docs/art_asset_prompt_guide.md` — where the open-animation art asset is specified.
