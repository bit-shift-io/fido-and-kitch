# TASKS — Center HUD Hearts/Coins at Top

Grill findings in `NOTES.md` (section "Center HUD Hearts/Coins at Top").

Scope: center the combined hearts + coin-counter row horizontally at the top of the
screen (currently left-aligned at `x = 16`). The whole block (hearts + optional coin
counter) is centered as one unit; when `coins == 0` the hearts alone are centered.
Y stays at `MARGIN = 16`. Centering recomputes every `draw()` so window resizes are
honored. Coin text width measured via `love.graphics.getFont():getWidth(text)`.

Run in order — each task depends on the previous. Verify each task with the commands
listed before moving on. The new test file is registered in Task 5; until then run it
by path.

- [x] Task 1 — Mock font measurement: in `tests/support/love_mock.lua`, the `love.graphics`
      table has `newFont = function() return {} end` (line 206) but NO `getFont`. Add
      `getFont = function() return {getWidth = function() return 0 end} end,` next to it
      (a `getWidth` on the returned font so `love.graphics.getFont():getWidth(text)` won't
      crash under the mock). Leave `newFont` as-is unless a test needs it.
      Verify: full `./test-unit.sh` still passes (no behavior change).

- [x] Task 2 — LivesHud startX param: in `src/ui/lives_hud.lua`, change
      `function LivesHud:draw()` to `function LivesHud:draw(startX)` with
      `local baseX = startX or MARGIN`, and draw each heart at
      `x = baseX + (i - 1) * (HEART_SIZE + HEART_SPACING)` (MARGIN now only the vertical
      margin, `y = MARGIN`). Default `startX = MARGIN` preserves today's top-left layout,
      so GameHud calling `self.livesHud:draw()` is unchanged.
      Verify: full `./test-unit.sh` — no regressions (GameHud still calls `draw()`).

- [x] Task 3 — Centering math tests: create `tests/unit/hud_centering_test.lua`
      (headless, just `local GameHud = require('src.ui.game_hud')` — no love, no EventBus
      clears) testing the white-box seam `GameHud._internal` (per AGENTS.md `_internal`
      pattern, like `Drawbridge._internal`):
      - `centerOffset(winW, blockW)` = `math.max(MARGIN, math.floor((winW - blockW) / 2))`:
        assert `centerOffset(800, 100) == 350`, `centerOffset(800, 800) == 16` (clamp,
        `(800-800)/2` is 0 → clamps to MARGIN), `centerOffset(800, 900) == 16` (block wider
        than window clamps to MARGIN), `centerOffset(800, 16) == 392`.
      - `heartRunWidth(lives)` = `lives * (HEART_SIZE + HEART_SPACING) - HEART_SPACING` when
        `lives > 0`, else 0: assert `heartRunWidth(0) == 0`, `heartRunWidth(1) == 24`,
        `heartRunWidth(3) == 88`.
      - `coinSegmentWidth(hasCoins, textWidth)` = `hasCoins and (HEART_SPACING + ICON_SIZE +
        TEXT_SPACING + textWidth) or 0` (leading HEART_SPACING is the gap between the last
        heart and the coin icon): assert `coinSegmentWidth(false, 30) == 0`,
        `coinSegmentWidth(true, 30) == 8 + 24 + 6 + 30`.
      - `blockWidth(lives, hasCoins, textWidth)` = `heartRunWidth + coinSegmentWidth`:
        assert `blockWidth(3, false, 30) == 88`, `blockWidth(3, true, 30) == 88 + 68`.
      Constants referenced must match game_hud.lua's locals (HEART_SIZE=24, HEART_SPACING=8,
      ICON_SIZE=24, TEXT_SPACING=6, MARGIN=16).
      Verify: `./test-unit.sh tests/unit/hud_centering_test.lua` FAILS (`_internal` is nil).

- [x] Task 4 — GameHud centering impl: in `src/ui/game_hud.lua`, add a white-box seam after
      the constants:
      `GameHud._internal = { centerOffset = ..., heartRunWidth = ..., coinSegmentWidth = ...,
      blockWidth = ... }` (pure functions implementing Task 3's math using the file's own
      constants). Rewrite `GameHud:draw()`:
      - compute `text = string.format('%d/%d', coins, total)` and
        `textWidth = love.graphics.getFont():getWidth(text)` only when `coins > 0`;
      - `local offset = GameHud._internal.centerOffset(love.graphics.getWidth(),
        GameHud._internal.blockWidth(lives, coins > 0, textWidth))`;
      - call `self.livesHud:draw(offset)` (was `:draw()`);
      - position the coin icon at `x = offset + GameHud._internal.heartRunWidth(lives) +
        HEART_SPACING` (was `MARGIN + self.getLives() * (HEART_SIZE + HEART_SPACING)`) and the
        text at `x + ICON_SIZE + TEXT_SPACING`, `y = MARGIN + TEXT_Y_OFFSET`. Keep the alpha
        re-apply after `livesHud:draw()` (it still resets colour to (1,1,1,1)). Existing
        `game_hud_test.lua` draw smoke (line 74) exercises the new `getFont` path.
      Verify: `./test-unit.sh tests/unit/hud_centering_test.lua` PASSES, then full
      `./test-unit.sh` (game_hud fade tests still green).

- [x] Task 5 — Register the test: append `'tests/unit/hud_centering_test.lua',` to
      `tests/unit/run.lua` `defaultTestFiles` (after line 25, `game_hud_test.lua`).
      Verify: full `./test-unit.sh` passes.

- [x] Task 6 — Doc update: in `ARCHITECTURE.md`, line 121, change "Draws heart squares
      top-left from `Lives` count." to reflect top-center placement (e.g. "Draws heart
      squares top-center from `Lives` count.").
      Verify: `grep -n "top-center" ARCHITECTURE.md` shows the updated line.
