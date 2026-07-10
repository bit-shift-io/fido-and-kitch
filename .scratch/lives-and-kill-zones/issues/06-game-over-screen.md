Status: done

# Game over screen

## What to build

When either player dies with the lives pool at zero, the game presents a game over screen with two options: **Restart Level** (reload the current map from scratch, exactly as if picked from the main menu — lives back to 2, coins/keys/switches reset) and **Main Menu** (back to the initial menu). The screen works with keyboard, gamepad/joystick, mouse, and touch, consistent with the main menu's input handling. This replaces issue 04's debug-print hook.

## Files to create/modify

- `src/game_states.lua` — add `GameOverState` alongside `MenuState`/`InGameState` (the game FSM in `src/game.lua` picks it up from the returned table automatically). It needs the full input-handler surface the other states implement (`keypressed`, `gamepadpressed`, `joystickpressed`, `mousepressed`, `touchpressed`, `update`, `draw`, `resize`, plus no-op `textinput`) — `MenuState` is the pattern, including how it maps inputs to `start`/`back`-style actions. Restart calls the same path as `MenuState:startGame` with the remembered map; Main Menu calls `game:setGameState('MenuState')`.
- `src/game_states.lua` (`InGameState`) — remember the map path passed to `load` (e.g. `self.currentMap = props.map or 'res/map/sandbox.lua'`) so restart can reload it; replace the game-over stub from issue 04 with `game:setGameState('GameOverState')` (pass the map path along).
- `src/ui/` — a simple two-option menu renderer if `GameOverState` warrants extracting one (`src/ui/map_list.lua` is prior art for a selectable list with keyboard/gamepad/pointer support); inline drawing in the state is also acceptable at this size.

## Test approach

Manual (`./run.sh`): burn all lives (die three times) → game over screen appears for everyone even if the other player was alive and standing safely. From the screen: Restart Level → same map reloads with 2 hearts, coins/keys/switches reset, spawn flash plays; Main Menu → initial menu screen, from which a new game starts cleanly. Exercise selection via keyboard, gamepad, and mouse click; check window resize doesn't break the layout. Headless: none new — the "death at 0 = game over" decision is already covered by `tests/lives_test.lua`.

## Acceptance criteria

- [ ] Third death (either player) shows the game over screen; gameplay stops
- [ ] Restart Level fully reloads the current map — equivalent to selecting it from the main menu (lives reset, level state reset)
- [ ] Main Menu returns to the initial menu screen, and starting a new game from there works
- [ ] Both options operable via keyboard, gamepad/joystick, mouse, and touch
- [ ] Works for any map, not just sandbox (map path is remembered, not hardcoded)

## Blocked by

02, 04.
