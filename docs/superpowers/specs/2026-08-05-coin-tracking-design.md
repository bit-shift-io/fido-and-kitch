# Per-Level Coin Tracking Design

Date: 2026-08-05
Status: Proposed

## Overview

Coins are the game's only pickable collectible besides keys, but collecting
one currently does nothing but play a sound, spawn a sparkle, and add an
entry to the player's inventory under an arbitrary Tiled object name. There
is no notion of how many coins a level holds or how many the player has
found.

This design makes coin collection meaningful: a per-level coin counter
tracked via the EventBus, surfaced in a unified game HUD that fades in and
out, and reported as a simple "X/Y coins collected" at the end of the
level. No extra-life pickups, no star ratings, no score persistence across
levels — deliberately out of scope.

## Requirements

- Count total coins in the level at load time.
- Count coins as they are collected, per level, resetting on each level
  load.
- Emit a `coin_collected` EventBus event whenever a player picks up a coin.
- Display a unified game HUD (hearts + coin counter) that:
  - is always visible while the camera is in `overview` (or `gameover`)
    mode,
  - fades in to full opacity whenever a coin is picked up or a life is
    lost (death/respawn),
  - holds briefly (~2s), then fades back out during normal `follow` play.
- Report the final `X/Y` coin count when the level ends (log only — no new
  screen, no rating math).

## Non-goals

- Extra-life ("1-up") pickups.
- Star ratings / percentage thresholds / rating math.
- Coin counter display in the menu or across levels (session persistence).
- Changing how keys or inventory work.

## Architecture

### 1. Coin pickup emits an event (`src/entities/coin.lua`, `src/player/player.lua`)

`src/entities/coin.lua` currently sets `itemName` from the arbitrary Tiled
object name. This is unusable as a stable signal, so it changes to the
constant `'coin'`:

```lua
itemName = function(object) return 'coin' end
```

`Player:pickup` (`src/player/player.lua`) already plays the pickup sound,
adds the item to inventory, and destroys the coin. After that existing
logic it gains a single guarded emit:

```lua
if pickup.itemName == 'coin' then
    EventBus.emit('coin_collected', {x = pickup.entity.sprite.position.x, y = pickup.entity.sprite.position.y})
end
```

Keys keep the existing inventory path untouched — their `itemName` is
`key_<color>` and never matches `'coin'`.

### 2. InGameState tracks coins (`src/states/ingame_state.lua`)

Mirrors the existing `cage_unlocked` / `player_died` pattern:

- At `InGameState:load`, count totals once:
  `self.totalCoins = #map:getEntitiesByType('coin')` and set
  `self.coinsCollected = 0`.
- Subscribe to `coin_collected` with a handler that increments
  `self.coinsCollected`.
- Unsubscription is already handled by the existing `EventBus.clear()` in
  `InGameState:exit()`.
- When the last player leaves the map (existing `onPlayerDestroyed`
  path), log the final count: `coinsCollected/totalCoins`.

### 3. Unified HUD (`src/ui/game_hud.lua`)

A single `GameHud` class owns both the hearts and the coin counter behind
one shared alpha. It contains a `LivesHud` instance for the hearts and
draws the coin counter itself; `InGameState:draw` replaces
`livesHud:draw()` with `gameHud:draw()`.

Behavior:

- **Opacity:** hidden during normal `follow` play, fully opaque in
  `overview`/`gameover` mode, and faded to full opacity on any trigger
  event, then held ~2s before fading back out.
- **Triggers:** `coin_collected` (coin pickup) and `player_died` (life
  lost, emitted at `src/player/player.lua:232`). Any trigger bumps
  a refresh timer and raises alpha.
- **Coin counter:** `res/img/ui_coin.png` icon + `X/Y` text drawn beside
  the hearts at the top of the screen, via `getCoins`/`getTotal`
  callbacks (same shape as `LivesHud`'s `getLives`).
- `GameHud` reads the camera mode via a `getCameraMode()` callback so the
  state stays decoupled from the camera object.

## Data flow

```
coin sprite touched
  → Pickup:contact → Player:pickup → EventBus.emit('coin_collected')
      → InGameState:onCoinCollected (increments counter)
      → GameHud (fade-in trigger + live X/Y display)
  → end of level → InGameState logs "X/Y coins collected"
```

## Error handling

- If a level has zero coins, `totalCoins == 0`; the counter displays
  `0/0` and the end-of-level report is a no-op safe log.
- The `coin_collected` guard on `itemName == 'coin'` keeps unrelated
  pickups (keys) from touching the counter.

## Testing

- Unit test: `coin.lua`'s `itemName` returns the constant `'coin'`
  (registered in `tests/unit/run.lua`).
- Integration test (via `tests/support/game_harness.lua` +
  `FakeInput`): load a real map with coins, walk a player onto a coin,
  assert `coin_collected` fires, `InGameState.coinsCollected`
  increments, and `totalCoins` equals the map's coin count.
- HUD test: `GameHud` alpha is 0 in `follow` mode, 1 in `overview` mode,
  and reacts to trigger events by fading up, holding ~2s, then fading
  down (headless — `love.graphics` via the existing mock).

## Constraints honored

- Follows the existing EventBus pattern (`cage_unlocked`, `player_died`).
- Follows the existing `LivesHud` component shape.
- No new globals; modules required where used.
- Headless-safe: coin counting and fade logic do not depend on live
  rendering.
