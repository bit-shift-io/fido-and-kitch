# Grill Notes — Center HUD Hearts/Coins at Top (2026-08-05)

## Task

Center the hearts + coin counter display at the top-center of the screen.
Currently left-aligned (hearts start at `x = MARGIN = 16`).

## Verified against code

- `src/ui/game_hud.lua` — GameHud wraps a `LivesHud` (`self.livesHud`) plus the coin
  counter. `draw()`: hearts at `MARGIN` (16,16) via `livesHud:draw()`; coin icon at
  `x = MARGIN + self.getLives() * (HEART_SIZE + HEART_SPACING)`, text at `x + ICON_SIZE + TEXT_SPACING`.
  Constants: `HEART_SIZE=24`, `HEART_SPACING=8`, `ICON_SIZE=24`, `MARGIN=16`, `TEXT_SPACING=6`, `TEXT_Y_OFFSET=6`.
- `src/ui/lives_hud.lua` — hearts at `x = MARGIN + (i-1) * (HEART_SIZE + HEART_SPACING)`,
  `y = MARGIN`. Ends by resetting colour to `(1,1,1,1)`.
- `src/states/ingame_state.lua:230` — `gameHud:draw()` called in screen space (after
  camera transform only applied to map draws), so `love.graphics.getWidth()` is the true
  window width. `InGameState:resize` exists → recompute centering per frame.
- `LivesHud` is used ONLY by `GameHud` in production code → change stays local to these two files.
- `tests/unit/game_hud_test.lua` — draw smoke test uses `LoveMock.new()`; mock already
  provides `love.graphics.getWidth() -> 800`, `love.graphics.print` no-op. Mock's
  `newFont` returns `{}` → needs `getWidth` added if we measure coin text width.
- `ARCHITECTURE.md:121` — says LivesHud draws "top-left"; update if text is touched.

## Confirmed user answers

- **Center the combined row.** Hearts + coin counter (when visible) form one horizontal
  row and that whole block is centered. When `coins == 0`, the hearts alone are centered.
  Layout/spacing unchanged — only the anchor moves. (User picked "Center combined row".)

## Design defaults (implementation decisions, confirm during planning)

- Center horizontally: `offset = (love.graphics.getWidth() - blockW) / 2`, clamped so the
  block never runs left of `MARGIN`. Block width = hearts run
  (`lives * (HEART_SIZE + HEART_SPACING) - HEART_SPACING`) + optional coin segment
  (`ICON_SIZE + TEXT_SPACING + textWidth`).
- Coin text width measured via `love.graphics.getFont():getWidth(text)`; add
  `getWidth = function() return 0 end` (or similar) to `love_mock`'s `newFont`.
- Y stays at `MARGIN = 16` ("top center"). Apply the same horizontal offset to hearts
  (needs `LivesHud:draw(xOffset)` or a `drawAt` param) and to the coin icon/text.
- Recompute every `draw()` so resizes are honored.

## Open questions

None. Grilling complete.

---

# Grill Notes — Per-Level Coin Tracking (2026-08-05)

Source docs: `docs/superpowers/specs/2026-08-05-coin-tracking-design.md` (Status: Proposed),
`docs/superpowers/plans/2026-08-05-coin-tracking-design.md` (5 tasks, ready to execute).

## Verified against code (all plan claims hold)

- `src/entities/coin.lua:8` — `itemName = function(object) return object.name end` (arbitrary Tiled name). Plan changes to constant `'coin'`.
- `src/player/player.lua:230-233` — `Player:resolveDeath` emits `player_died` positionally: `EventBus.emit('player_died', self, self.deathType)`.
- `src/player/player.lua:273-282` — `Player:pickup` plays sound, `inventory:addItems`, `entity:queueDestroy()`. Plan adds guarded `coin_collected` emit before destroy.
- `src/states/ingame_state.lua:72-85` — `cage_unlocked` pattern (count at load, `EventBus.on` subscribe). Coin counter mirrors it.
- `src/states/ingame_state.lua:107-116` — `onPlayerDied(player, deathType)` positional; plan upgrades to `{player, deathType}` table (Task 4). Only consumer besides the emit.
- `src/states/ingame_state.lua:133-144` — `onPlayerDestroyed` removes player; `playerCount == 0` branch → `setGameState('MenuState')`. Plan adds coin report log here (exit-door level end).
- `src/states/ingame_state.lua:146-148` — `exit()` calls `EventBus.clear()`, so no manual unsubscribe needed.
- `src/ui/lives_hud.lua:37` — `:draw` ends with `love.graphics.setColor(1,1,1,1)`; GameHud must re-apply alpha after hearts (plan's "wrinkle" is real).
- `src/player/player_states.lua:301-326` — `DeadState` blinks then `resolveDeath()`; death does NOT destroy the player entity, so `onPlayerDestroyed` fires only via the exit door. Plan's level-end path claim holds.
- `src/map/init.lua:184` — `getEntitiesByType` exists; coin entities live in `layer.entities`, so load-time count works.
- `src/components/pickup.lua:22` — `Pickup:contact` → `entity:pickup(self.pickup)`.
- Assets/fixtures present: `res/img/ui_coin.png` (128x128), `tests/fixtures/coin_room.lua` (spawn 64,128 32x32; coin `coin1` 120,160 20x20 → centre 130,170), `tests/fixtures/kill_zone_room.lua`.
- `tests/support/love_mock.lua` has NO `love.graphics.print` (plan adds a no-op).

## Decisions confirmed so far

- Alpha is drawn via ambient `love.graphics.setColor`, FlashEffect idiom — no Sprite alpha field.
- Coin counter hidden until `getCoins() > 0` (never `0/0`).
- HUD hidden in `follow`, opaque in `overview`/`gameover`, fades in on `coin_collected`/`player_died` (1.2s in, hold 2.0s, 1.2s out).
- Keys (`key_<color>`) never match `'coin'`, untouched.
- Execution choice (subagent-driven vs inline) still open at plan end.

## Confirmed user answers

- **No end-of-level X/Y report.** User: "I dont want a report at the end of the game. Simple having it on the gui is enough." → Drop the `Log.info('Level complete: X/Y coins collected')` from `InGameState:onPlayerDestroyed`, drop `tests/unit/ingame_coin_report_test.lua` (and its registration in `tests/unit/run.lua`). The HUD coin counter is the only surface. `totalCoins`/`coinsCollected` still needed — the HUD's `getCoins`/`getTotal` callbacks read them. Implication: this also covers both exit-door AND game-over paths — never report.
- **Keep Task 4 (player_died → `{player, deathType}` table payload).** User's stated motivation: "keep things consistent in the game. A standard way of reporting." Kept — it's internal API hygiene, low-risk (2 verified touchpoints, no tests reference the old shape), and makes all three event payloads uniform.
- **Keep the HUD fade design.** Counter fades in on `coin_collected`/`player_died` (1.2s in, hold 2.0s, 1.2s out), fully visible in `overview`/`gameover`, hidden in follow. Confirmed even though the report is gone — the fade is the intended presentation.

## Final trimmed scope (diff vs plan)

- Task 3: drop the `Log.info('Level complete: X/Y coins collected')` line in `onPlayerDestroyed`, drop `tests/unit/ingame_coin_report_test.lua` + its `run.lua` registration, drop that file from the Task 3 `git add`. Keep: `totalCoins`/`coinsCollected` tracking in `load`, `onCoinCollected` handler, and the integration assertion test. `onPlayerDestroyed` stays untouched.
- Tasks 1, 2, 4, 5 unchanged.
- Pending: amend `docs/superpowers/specs/2026-08-05-coin-tracking-design.md` (drop the "Report the final X/Y coin count when the level ends" requirement + its Data flow/Error-handling mentions) and `docs/superpowers/plans/2026-08-05-coin-tracking-design.md` (Execution Summary + carried design decisions) so an executing agent doesn't re-add the report. The plan currently still names the report in Task 3 and its summary.

## Open questions

None remaining. Grilling complete.
