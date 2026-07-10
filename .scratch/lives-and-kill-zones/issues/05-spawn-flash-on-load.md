Status: pending

# Spawn flash on map load

## What to build

When a level starts, both players flash a few times at their spawn point — the same non-blocking spawn flash used after a respawn — so players (especially kids) can immediately locate their characters. Movement is live from the first frame. This is a placeholder for a future spawn animation.

## Files to create/modify

- `src/game_states.lua` — in `InGameState:load`, after players are spawned, trigger the spawn flash on each player (reuse the flash path built in issue 04).
- `src/player/player.lua` or `src/player/player_states.lua` — only if a small refactor is needed to trigger the spawn flash outside the respawn flow.

## Test approach

Manual: start any level from the menu — both players flash at spawn and can move immediately during the flash; restart/reload and confirm it happens every load. Headless: none (purely visual).

## Acceptance criteria

- [ ] Both players flash on every level load, at their spawn points
- [ ] Players are controllable during the flash (no input lag)
- [ ] Identical flash behaviour to the respawn flash (single shared helper)

## Blocked by

04 (reuses the flash helper and spawn-flash path).
