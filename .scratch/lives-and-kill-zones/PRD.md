# Water Kill Zones, Shared Lives & Game Over

## Problem Statement

Players can currently fall into the water in the sandbox level (and by extension any hazard in any level) with no consequence — the water is purely visual. There is no concept of dying, no penalty for mistakes, and no failure state, so levels have no stakes. Players (including young kids) also have no visual cue for how many chances they have left, and when a player moves suddenly (spawn or respawn) there is nothing drawing the eye to where their character now is.

## Solution

Levels gain designer-placed **kill zones** — invisible rectangles drawn in Tiled that kill any player who touches them. Kill zones are decoupled from the visual water tiles, so the designer can let players sink partway into water before dying, or extend zones past the map edge.

The two players share a single **pool of lives** (default 2, always reset on level load). When a player is killed, the pool is decremented, the killed player locks in place and flashes, then respawns at the last place they were standing stably on safe ground and flashes again so the player can find themselves. The other player and all level state are untouched, so play continues. The remaining lives are shown as a row of hearts at the top-left of the screen; each death removes a heart. Playing with zero hearts is the "last chance" state: the next death of *either* player triggers a **game over screen** offering "restart level" (a full reload, as if picked from the main menu) or "return to main menu".

Each kill zone carries a **death type** (e.g. `water`) so that, later, different death animations can be played per hazard. For now every death uses the same presentation: lock in place and flash the sprite a few times.

## User Stories

1. As a player, I want to be killed when I fall into water, so that hazards have stakes.
2. As a player, I want to sink slightly into the water before dying (where the designer allows it), so that death feels fair rather than hair-trigger.
3. As a player, I want to respawn at the last spot I was standing stably on safe ground, so I can retry the jump I just failed.
4. As a player, I want my character to flash when respawning (and on initial spawn), so I can immediately find where my character is.
5. As a player, I want my character to lock in place and flash when killed, so I understand a death happened rather than the character teleporting confusingly.
6. As a player, I want to keep moving immediately when I spawn/respawn, so the flash never feels like input lag.
7. As a pair of players, we want to share one pool of lives, so the game is cooperative.
8. As the surviving player, I want to be unaffected when my partner dies and respawns, so I can keep playing.
9. As players, we want collected coins, flipped switches, and picked-up keys to persist through a respawn, so a death isn't a full reset.
10. As a player (especially a kid), I want to see remaining lives as a row of hearts at the top-left, so I can tell at a glance how many chances are left.
11. As a player, I want a heart to disappear each time we die, so the cost of a death is visible.
12. As players, when either of us dies with zero hearts showing, we want a game over screen, so the failure state is clear.
13. As a player on the game over screen, I want to restart the current level (full reload — coins, keys, switches all reset), so we can try again.
14. As a player on the game over screen, I want to return to the main menu, so we can pick a different level.
15. As a player, I want the game over screen to work with keyboard, gamepad, mouse, and touch, consistent with the main menu.
16. As a level designer, I want to draw kill zone rectangles in Tiled on an object layer, independent of the visual water tiles, so gameplay and art are decoupled.
17. As a level designer, I want to tag each kill zone with a death type, so different hazards can get different death animations later.
18. As a level designer, I want lives to reset to the default on every level load (menu start, restart, or progressing to a new level), so each level is a fresh set of chances.
19. As a player, I want to not respawn on the very pixel of a ledge edge above water; the respawn point should be somewhere I was *stably* grounded, so I don't die repeatedly on respawn.

## Implementation Decisions

- **Kill zones are object-layer entities**, following the existing pattern where object layers become entities at map load (the same machinery that builds ladders, teleports, coins). A kill zone is a static sensor volume with an `isKillZone` flag and a `deathType` string read from its Tiled object properties. No tile-layer support for now.
- **Detection is a player-side overlap query** each update, mirroring how the player queries for ladders, rather than physics enter/exit callbacks.
- **Lives live on the in-game state object** (the shared pool), not on either player. Initialised to 2 on every level load. The default lives value is defined in one place.
- **Lives/death arithmetic goes in a pure seam module** (a la the existing player-movement seam): given current lives, a death event returns "respawn, new lives count" or "game over". This is the headless-testable core.
- **Safe-position tracking is per player**: while a player is in the grounded state, a timer accumulates; after a stability threshold (~0.5 s of continuous grounding), the current position is recorded as that player's respawn point. Leaving the ground resets the timer. The threshold logic is a pure seam module. The initial safe position is the spawn point.
- **Death and spawn become player FSM states.** `DeadState`: collider set kinematic with zero gravity (the ladder state already demonstrates this lock technique), input ignored, sprite flashes a few times, then transitions out by respawning (teleport collider to safe position) or by signalling game over. `SpawnState` (or a flash-only variant): sprite flashes a few times but movement/input is live immediately — it decorates the normal states rather than replacing control. Spawn flash also plays on initial map load.
- **Sprite flashing** is a small reusable visibility-blink helper (toggle draw on/off on a timer, N blinks over a fixed duration) usable by both death and spawn.
- **Death type is plumbed through**: the kill event carries the zone's `deathType` into the death state, which for now ignores it (single flash presentation) but keeps the value so per-type animations can be added later without re-plumbing.
- **Game over is a new game-level FSM state** alongside the existing menu and in-game states. It renders a simple two-option screen (Restart Level / Main Menu) and handles keypressed / gamepadpressed / joystickpressed / mousepressed / touchpressed, following the main menu's input conventions. The in-game state must remember which map file it loaded so restart can reload it exactly as if chosen from the menu.
- **HUD renders in screen space** (after the map draw, outside the map's canvas/scale transform): one red square per remaining life, drawn at the top-left. The square is an explicit placeholder for a future heart sprite.

## Testing Decisions

- Good tests here assert **gameplay decisions, not rendering**: lives arithmetic (2 → 1 → 0 → game over on next death), safe-position recording (only after the stability threshold; reset when airborne), and kill-zone overlap decision given player bounds and zone rects.
- Prior art: `tests/player_movement_test.lua` testing the pure `player_movement` seam, run headlessly via `./test.sh` (dependency-free runner, no LÖVE window).
- New pure seam modules (lives arithmetic, safe-position tracker, flash timing if non-trivial) each get a `tests/<name>_test.lua` following that convention — this project's established naming, used instead of the generic `.unit.test.*` convention.
- Flash visuals, HUD layout, and the game over screen are verified by running the game (`./run.sh`), not by headless tests.

## Out of Scope

- Death animations beyond the flash (the death type is recorded but unused for presentation).
- Spawn animations beyond the flash.
- Heart artwork (red square placeholder only) and any HUD beyond the lives row.
- Tile-layer kill zones (object layers only).
- Checkpoints, health points, invulnerability frames, or damage that isn't instantly fatal.
- Lives carrying over between levels, extra-life pickups, or difficulty settings.
- Hazard re-check at the respawn point (respawning into a now-dangerous spot is accepted for now).
- Kill zones in maps other than sandbox (other maps can adopt the same layer pattern later).

## Acceptance Criteria

- [ ] Sandbox map has a kill-zone object layer over the water, with `deathType` set to `water`.
- [ ] A player overlapping a kill zone dies; the kill zone can be shaped so the player visibly sinks into the water first.
- [ ] On death with lives remaining: shared lives decrement by 1, the dead player locks in place and flashes, then respawns at their last stably-grounded position and flashes again, movable immediately.
- [ ] The other player and all level state (coins, keys, switches) are unaffected by a death.
- [ ] Lives start at 2 on every level load and are shown as a row of red squares top-left; one disappears per death; zero squares = last chance.
- [ ] When either player dies with lives at 0, a game over screen appears for everyone.
- [ ] Game over screen offers Restart Level (full reload of the current map) and Main Menu (back to the initial menu), operable by keyboard, gamepad, mouse, and touch.
- [ ] Players flash on initial spawn at map load.
- [ ] `./test.sh` passes, including new tests for lives arithmetic and safe-position tracking.

## References

- Grill Q&A and rationale: `DECISIONS.md` (this feature folder)
- Glossary: `CONTEXT.md` (project root) — Kill zone, Death type, Lives pool, Last safe position
- Prior art: existing ladder volumes (object-layer sensor entities), player-movement testability seam
