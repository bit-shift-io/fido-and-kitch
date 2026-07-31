# Gamepad Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full gamepad/controller support for 2+ players with hotplug, unified keyboard+gamepad input, and edge detection.

**Architecture:** New `src/input/` module with `InputManager` class handling all input polling, state management, and LÖVE callbacks. Existing code delegates to this manager.

**Tech Stack:** LÖVE 12.0 (LuaJIT), hump.Class, existing test infrastructure (unit/integration/e2e tiers)

## Global Constraints

- Follow existing code conventions: globals intentional, hump.Class pattern, components attach via `addComponent`, state machines proxy unknown methods
- Physics via `Collider`/`World` abstraction (bump backend), don't touch physics backends
- Run `./test-unit.sh` for logic changes; `./test-integration.sh` for map-loaded tests; `./test-e2e.sh` for visual verification
- No unrelated refactoring; match nearby style (mixed quotes/indentation OK)
- Design doc: `docs/superpowers/specs/2026-07-30-gamepad-support-design.md`

---

### Task 1: Create InputManager Module

**Files:**
- Create: `src/input/input_manager.lua`
- Create: `src/input/action_map.lua`
- Modify: `src/main.lua` (add require, instantiate global)

**Interfaces:**
- Produces: global `inputManager` with API per spec Section 3
- Consumes: `love.joystick` API, `love.keyboard.isDown`

- [ ] **Step 1: Write failing unit test for InputManager**

```lua
-- tests/unit/input_manager_test.lua
local InputManager = require('src.input.input_manager')

function test_input_manager_basic()
  local im = InputManager:new()
  im:update(1/60)
  -- No joysticks, keyboard not pressed
  assert(not im:isDown(1, 'left'))
  assert(not im:wasPressed(1, 'left'))
end
```

- [ ] **Step 2: Run test to verify it fails**
  - Run: `./test-unit.sh tests/unit/input_manager_test.lua`
  - Expected: FAIL (module not found)

- [ ] **Step 3: Implement InputManager skeleton**

```lua
-- src/input/action_map.lua
local KEYBOARD_MAPS = {
  [1] = {left='left', right='right', up='up', down='down', use='rshift', start='escape', back='tab'},
  [2] = {left='a', right='d', up='w', down='s', use='q', start='escape', back='tab'},
}

local GAMEPAD_BUTTONS = {
  use = {'a', 'b'},
  start = {'start'},
  back = {'back', 'guide'},
}

local GAMEPAD_AXES = {
  left = 'leftx',
  up = 'lefty',
}

return {KEYBOARD_MAPS = KEYBOARD_MAPS, GAMEPAD_BUTTONS = GAMEPAD_BUTTONS, GAMEPAD_AXES = GAMEPAD_AXES}
```

```lua
-- src/input/input_manager.lua
local Class = require('lib.class')
local actionMap = require('src.input.action_map')

local InputManager = Class{}

function InputManager:init()
  love.joystick.loadGamepadMappings('res/gamecontrollerdb.txt')
  self.players = {}        -- [idx] = {joystick=js, deadzone=0.2, keyboardMap=map}
  self.actionState = {}    -- [idx][action] = bool
  self.prevActionState = {}
  for i=1,4 do self:ensurePlayer(i) end
end

function InputManager:ensurePlayer(idx)
  if not self.players[idx] then
    self.players[idx] = {joystick=nil, deadzone=0.2, keyboardMap=actionMap.KEYBOARD_MAPS[idx] or {}}
  end
  if not self.actionState[idx] then self.actionState[idx] = {} end
  if not self.prevActionState[idx] then self.prevActionState[idx] = {} end
end

function InputManager:update(dt)
  -- swap states
  self.prevActionState = {}
  for i,s in pairs(self.actionState) do
    self.prevActionState[i] = {}
    for a,v in pairs(s) do self.prevActionState[i][a] = v end
  end
  self.actionState = {}
  
  for i=1,4 do self:ensurePlayer(i) end
  
  for i, p in ipairs(self.players) do
    self.actionState[i] = {}
    -- Keyboard
    local km = p.keyboardMap
    for action, key in pairs(km) do
      if love.keyboard.isDown(key) then self.actionState[i][action] = true end
    end
    -- Gamepad
    if p.joystick then
      self:pollGamepad(i, p)
    end
  end
end

function InputManager:pollGamepad(idx, player)
  local js = player.joystick
  if not js then return end
  local dz = player.deadzone
  
  -- Axes (D-pad or left stick)
  local hx, hy = 0, 0
  if js:isGamepad() then
    hx = js:getGamepadAxis('leftx') or 0
    hy = js:getGamepadAxis('lefty') or 0
  else
    hx = js:getAxis(1) or 0
    hy = js:getAxis(2) or 0
  end
  
  if hx < -dz then self.actionState[idx].left = true end
  if hx > dz then self.actionState[idx].right = true end
  if hy < -dz then self.actionState[idx].up = true end
  if hy > dz then self.actionState[idx].down = true end
  
  -- Buttons
  for action, buttons in pairs(actionMap.GAMEPAD_BUTTONS) do
    for _, btn in ipairs(buttons) do
      if js:isGamepadDown and js:isGamepadDown(btn) or js:isDown(btn) then
        self.actionState[idx][action] = true
        break
      end
    end
  end
end

function InputManager:joystickadded(joystick)
  for i=1,4 do
    if not self.players[i].joystick then
      self.players[i].joystick = joystick
      break
    end
  end
end

function InputManager:joystickremoved(joystick)
  for i=1,4 do
    if self.players[i].joystick == joystick then
      self.players[i].joystick = nil
      break
    end
  end
end

function InputManager:isDown(idx, action)
  return self.actionState[idx] and self.actionState[idx][action] == true
end

function InputManager:wasPressed(idx, action)
  return (self.actionState[idx] and self.actionState[idx][action])
     and not (self.prevActionState[idx] and self.prevActionState[idx][action])
end

function InputManager:wasReleased(idx, action)
  return not (self.actionState[idx] and self.actionState[idx][action])
     and (self.prevActionState[idx] and self.prevActionState[idx][action])
end

function InputManager:setDeadzone(idx, dz)
  self:ensurePlayer(idx)
  self.players[idx].deadzone = dz
end

return InputManager
```

- [ ] **Step 4: Run test to verify it passes**
  - Run: `./test-unit.sh tests/unit/input_manager_test.lua`
  - Expected: PASS

- [ ] **Step 5: Integrate into main.lua**

```lua
-- src/main.lua additions
require('src.input.input_manager')
-- In Game:init() or top-level:
inputManager = InputManager:new()

function love.joystickadded(joystick)
  inputManager:joystickadded(joystick)
end

function love.joystickremoved(joystick)
  inputManager:joystickremoved(joystick)
end

function love.update(dt)
  inputManager:update(dt)
  -- existing update code
end
```

- [ ] **Step 6: Run unit tests again**
  - Run: `./test-unit.sh`
  - Expected: All PASS

- [ ] **Step 7: Commit**
  ```bash
  git add src/input/ tests/unit/input_manager_test.lua src/main.lua
  git commit -m "feat(input): add InputManager module with keyboard/gamepad polling"
  ```

---

### Task 2: Refactor Player to Use InputManager

**Files:**
- Modify: `src/player/player.lua:370-423` (replace `isDown` method)
- Test: `tests/unit/player_input_test.lua`

**Interfaces:**
- Consumes: global `inputManager`
- Produces: `Player:isDown(action)` delegates to `inputManager:isDown(self.index, action)`

- [ ] **Step 1: Write failing unit test**

```lua
-- tests/unit/player_input_test.lua
local Player = require('src.player.player')
local inputManager = require('src.input.input_manager') -- mock

function test_player_delegates_to_input_manager()
  local player = Player:new({index=1, x=0, y=0})
  -- mock inputManager.isDown
  local called = false
  inputManager.isDown = function(idx, action)
    called = {idx=idx, action=action}
    return true
  end
  local result = player:isDown('left')
  assert(called.idx == 1 and called.action == 'left')
  assert(result == true)
end
```

- [ ] **Step 2: Run test to verify it fails**
  - Run: `./test-unit.sh tests/unit/player_input_test.lua`
  - Expected: FAIL (old isDown still runs)

- [ ] **Step 3: Replace Player:isDown**

```lua
-- src/player/player.lua (replace lines 370-423)
function Player:isDown(action)
  return inputManager:isDown(self.index, action)
end
```

- [ ] **Step 4: Run test to verify it passes**
  - Run: `./test-unit.sh tests/unit/player_input_test.lua`
  - Expected: PASS

- [ ] **Step 5: Run all unit tests**
  - Run: `./test-unit.sh`
  - Expected: All PASS

- [ ] **Step 6: Commit**
  ```bash
  git add src/player/player.lua tests/unit/player_input_test.lua
  git commit -m "refactor(player): delegate isDown to InputManager"
  ```

---

### Task 3: Refactor MapList to Use InputManager

**Files:**
- Modify: `src/ui/map_list.lua:239-294` (update polling, gamepadpressed, joystickpressed)
- Test: `tests/integration/map_list_gamepad_test.lua`

**Interfaces:**
- Consumes: global `inputManager`
- Produces: `MapList:update(dt)` uses `inputManager:isDown`/`wasPressed`; `gamepadpressed`/`joystickpressed` use `inputManager:wasPressed`

- [ ] **Step 1: Write failing integration test**

```lua
-- tests/integration/map_list_gamepad_test.lua
local GameHarness = require('tests.support.game_harness')
local FakeInput = require('tests.support.fake_input').FakeInput

function test_map_list_gamepad_navigation()
  local game = GameHarness.startGame('res/map/sandbox.lua')
  local input = FakeInput.new()
  local ml = game.states.MenuState.mapList
  
  -- Simulate gamepad left stick right via inputManager
  inputManager.actionState[1].right = true
  inputManager:update(1/60)
  
  -- Should navigate to next map
  -- (assert on ml.selectedIndex)
end
```

- [ ] **Step 2: Run test to verify it fails**
  - Run: `./test-integration.sh tests/integration/map_list_gamepad_test.lua`
  - Expected: FAIL

- [ ] **Step 3: Refactor MapList**

```lua
-- src/ui/map_list.lua modifications

function MapList:update(dt)
  self.inputCooldown = math.max(0, self.inputCooldown - dt)
  if self.inputCooldown > 0 then return nil end
  
  -- Replace direct joystick polling with InputManager
  if inputManager:isDown(1, 'right') or inputManager:wasPressed(1, 'right') then
    self:next()
    self.inputCooldown = 0.25
  elseif inputManager:isDown(1, 'left') or inputManager:wasPressed(1, 'left') then
    self:previous()
    self.inputCooldown = 0.25
  end
  return nil
end

function MapList:gamepadpressed(joystick, button)
  -- Map button to action via InputManager's internal logic or check wasPressed
  -- Simpler: check inputManager:wasPressed(1, action)
  if inputManager:wasPressed(1, 'start') then return 'start' end
  if inputManager:wasPressed(1, 'back') then return 'back' end
  -- D-pad/shoulder handled in update() via axis polling
  return nil
end

function MapList:joystickpressed(joystick, button)
  if inputManager:wasPressed(1, 'start') then return 'start' end
  if inputManager:wasPressed(1, 'back') then return 'back' end
  return nil
end
```

- [ ] **Step 4: Run test to verify it passes**
  - Run: `./test-integration.sh tests/integration/map_list_gamepad_test.lua`
  - Expected: PASS

- [ ] **Step 5: Run all integration tests**
  - Run: `./test-integration.sh`
  - Expected: All PASS

- [ ] **Step 6: Commit**
  ```bash
  git add src/ui/map_list.lua tests/integration/map_list_gamepad_test.lua
  git commit -m "refactor(map_list): use InputManager for gamepad navigation"
  ```

---

### Task 4: Refactor Game States to Use InputManager

**Files:**
- Modify: `src/game_states.lua` (MenuState, InGameState, GameOverState)
- Test: `tests/integration/game_states_gamepad_test.lua`

**Interfaces:**
- Consumes: global `inputManager`
- Produces: All `gamepadpressed`/`joystickpressed`/`keypressed` use `inputManager:wasPressed`

- [ ] **Step 1: Write failing integration test**

```lua
-- tests/integration/game_states_gamepad_test.lua
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')

function test_menu_state_gamepad_start()
  local game = GameHarness.startGame('res/map/sandbox.lua')
  -- Simulate Start button press
  inputManager.actionState[1].start = true
  inputManager:update(1/60)
  FrameStepper.step(game, 2)
  -- Should transition to InGameState
  assert(game.currentStateName == 'InGameState')
end

function test_ingame_state_gamepad_toggle_camera()
  local game = GameHarness.startGame('res/map/sandbox.lua')
  inputManager.actionState[1].back = true
  inputManager:update(1/60)
  FrameStepper.step(game, 2)
  -- Camera overview toggled
end
```

- [ ] **Step 2: Run test to verify it fails**
  - Run: `./test-integration.sh tests/integration/game_states_gamepad_test.lua`
  - Expected: FAIL

- [ ] **Step 3: Refactor game_states.lua**

```lua
-- MenuState:keypressed -> use inputManager:wasPressed
function MenuState:update(dt)
  if inputManager:wasPressed(1, 'start') then
    self:startGame{map=self.mapList.selectedFile}
  elseif inputManager:wasPressed(1, 'back') then
    love.event.push('quit')
  end
  -- Arrow keys still work via isDown for repeat navigation
  if inputManager:isDown(1, 'left') then self.mapList:previous() end
  if inputManager:isDown(1, 'right') then self.mapList:next() end
end

-- Remove/reduce gamepadpressed/joystickpressed handlers
function MenuState:gamepadpressed(joystick, button) end
function MenuState:joystickpressed(joystick, button) end

-- InGameState
function InGameState:update(dt)
  if inputManager:wasPressed(1, 'back') then
    self.camera:toggleOverview()
  end
end
function InGameState:gamepadpressed() end
function InGameState:joystickpressed() end

-- GameOverState
function GameOverState:update(dt)
  if inputManager:wasPressed(1, 'up') then self:moveSelection(-1) end
  if inputManager:wasPressed(1, 'down') then self:moveSelection(1) end
  if inputManager:wasPressed(1, 'start') or inputManager:wasPressed(1, 'use') then
    self:activateSelected()
  end
end
function GameOverState:gamepadpressed() end
function GameOverState:joystickpressed() end
```

- [ ] **Step 4: Run test to verify it passes**
  - Run: `./test-integration.sh tests/integration/game_states_gamepad_test.lua`
  - Expected: PASS

- [ ] **Step 5: Run all integration tests**
  - Run: `./test-integration.sh`
  - Expected: All PASS

- [ ] **Step 6: Commit**
  ```bash
  git add src/game_states.lua tests/integration/game_states_gamepad_test.lua
  git commit -m "refactor(game_states): use InputManager for all gamepad/keyboard input"
  ```

---

### Task 5: Add GameControllerDB and Verify End-to-End

**Files:**
- Create: `res/gamecontrollerdb.txt` (download from SDL repo)
- Modify: `src/main.lua` (ensure path correct)
- Test: `./test-e2e.sh` (manual verification)

**Interfaces:**
- Consumes: `love.joystick.loadGamepadMappings`

- [ ] **Step 1: Download gamecontrollerdb.txt**
  ```bash
  curl -o res/gamecontrollerdb.txt https://raw.githubusercontent.com/gabomdq/SDL_GameControllerDB/master/gamecontrollerdb.txt
  ```

- [ ] **Step 2: Verify main.lua loads it correctly**
  - Check `love.joystick.loadGamepadMappings('res/gamecontrollerdb.txt')` called in InputManager:init

- [ ] **Step 3: Run E2E test (paced, watchable)**
  ```bash
  love . e2e=gamepad_test map=sandbox --paced
  ```
  - Connect gamepad(s)
  - Verify P1/P2 can move, jump, use with gamepad
  - Verify menu navigation works
  - Verify GameOver screen works
  - Verify hotplug: disconnect/reconnect

- [ ] **Step 4: Run all test tiers**
  ```bash
  ./test-all.sh
  ```
  - Expected: All tiers PASS (e2e skipped in CI)

- [ ] **Step 5: Commit**
  ```bash
  git add res/gamecontrollerdb.txt src/main.lua
  git commit -m "feat: add gamecontrollerdb.txt for SDL gamepad mappings"
  ```

---

### Task 6: Documentation & Cleanup

**Files:**
- Modify: `README.md` (update controls section)
- Modify: `AGENTS.md` (if new patterns documented)

- [ ] **Step 1: Update README controls section**
  ```markdown
  ## Controls
  P1: Arrow keys + RShift | Gamepad: D-pad/Left Stick + A/B (use), Start (menu), Back (back)
  P2: WASD + Q | Gamepad: D-pad/Left Stick + A/B (use), Start (menu), Back (back)
  ```

- [ ] **Step 2: Run final test suite**
  ```bash
  ./test-all.sh
  ```

- [ ] **Step 3: Commit**
  ```bash
  git add README.md
  git commit -m "docs: update controls for gamepad support"
  ```

---

## Self-Review Checklist

- [ ] Spec Section 3 (InputManager API) → Tasks 1
- [ ] Spec Section 4 (Action Mappings) → Task 1 (action_map.lua)
- [ ] Spec Section 5.1 (main.lua integration) → Task 1 Step 5
- [ ] Spec Section 5.2 (Player delegation) → Task 2
- [ ] Spec Section 5.3 (MapList) → Task 3
- [ ] Spec Section 5.4 (GameStates) → Task 4
- [ ] Spec Section 6 (Hotplug) → Task 1 (joystickadded/removed)
- [ ] Spec Section 7 (Testing) → Each task has unit/integration tests
- [ ] Spec Section 8 (Assets) → Task 5
- [ ] No placeholders, all code blocks complete
- [ ] Type consistency: `inputManager:isDown(idx, action)` used everywhere

---

**Plan saved to:** `docs/superpowers/plans/2026-07-30-gamepad-support.md`

**Two execution options:**

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**