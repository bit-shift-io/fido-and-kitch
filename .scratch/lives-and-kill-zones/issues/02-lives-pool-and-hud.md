Status: pending

# Shared lives pool + hearts HUD

## What to build

The level tracks a shared pool of lives, reset to 2 on every level load, and displays it as a horizontal row of red squares (heart placeholders) at the top-left of the screen. After this slice, starting any level shows two red squares, and a temporary debug key decrements the pool — one square disappears per press, and at zero the row is empty. The decision "does this death consume a life or trigger game over?" lives in a pure, headless-tested seam module, ready for issues 04 and 06 to consume.

## Files to create/modify

- `src/player/lives.lua` (new seam module, pattern: `src/player/player_movement.lua`) — pure functions, e.g. `Lives.defaultCount()` returning 2 and `Lives.applyDeath(lives)` returning `{lives=<n>, outcome='respawn'|'gameover'}`: death at 1+ lives decrements and respawns; death at 0 lives is game over.
- `src/ui/lives_hud.lua` (new) — draws one red rectangle per remaining life in a row at the top-left, in screen space. Plain `love.graphics` rectangles; sized/spacing chosen by feel. The red square is an explicit placeholder for a future heart sprite.
- `src/game_states.lua` — in `InGameState:load`, set `self.lives = Lives.defaultCount()` (this runs on every level load, so reset comes free). In `InGameState:draw`, draw the HUD **after** `map:draw()` so it sits above the map and outside the map's canvas scaling. Add a temporary debug key in `InGameState:keypressed` to decrement lives (remove in issue 04 or 06 once real deaths drive it).
- `tests/lives_test.lua` (new) — headless tests for the seam.

## Test approach

Headless (`./test.sh`): `applyDeath` at 2 → 1/respawn, at 1 → 0/respawn, at 0 → gameover; default is 2. Manual: run the game, see two squares top-left at correct position regardless of window resize; debug-decrement to zero and confirm the empty row; return to menu, reload a level, confirm the pool resets to 2.

## Acceptance criteria

- [ ] Lives initialise to 2 on every level load (menu start or any reload)
- [ ] HUD shows one red square per remaining life at the top-left, in screen space, above the map
- [ ] Zero lives renders an empty row (last-chance state) — no crash, no negative squares
- [ ] `tests/lives_test.lua` passes via `./test.sh`, covering the 2 → 1 → 0 → gameover progression

## Blocked by

None — can start immediately (parallel with 01 and 03).
