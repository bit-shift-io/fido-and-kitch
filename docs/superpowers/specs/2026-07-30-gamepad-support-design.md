# Gamepad Support Design

**Date:** 2026-07-30  
**Status:** Approved for Implementation

---

## 1. Overview

Add full gamepad/controller support for 2+ players in Fido and Kitch. Currently the game only supports keyboard (P1: arrows + rshift, P2: WASD + Q). This design introduces an `InputManager` that unifies keyboard and gamepad input, supports hotplug, and provides edge-detection (pressed/released) for all actions.

---

## 2. Architecture

### 2.1 New Module: `src/input/`

```
src/input/
├── input_manager.lua      # Core input polling, state management
├── action_map.lua         # Keyboard/gamepad action mappings
```

### 2.2 Global Integration

- `InputManager` instantiated in `src/main.lua` as global `inputManager`
- Hooks into LÖVE callbacks: `love.joystickadded`, `love.joystickremoved`, `love.update`
- Existing `Player:isDown()` delegates to `InputManager:isDown(playerIndex, action)`
- Menu/UI states (`MenuState`, `GameOverState`, `MapList`) use `InputManager` for all player input

---

## 3. InputManager API

```lua
-- src/input/input_manager.lua
InputManager = Class{}

function InputManager:init()
  love.joystick.loadGamepadMappings('res/gamecontrollerdb.txt')
  self.players = {}           -- [playerIndex] = {joystick, deadzone, keyboardMap}
  self.actionState = {}       -- [playerIndex][action] = boolean (current frame)
  self.prevActionState = {}   -- [playerIndex][action] = boolean (previous frame)
end

-- Call once per frame in love.update(dt)
function InputManager:update(dt)
  self.prevActionState = deepcopy(self.actionState)
  self.actionState = {}
  -- Poll keyboard + gamepad for each player slot
end

-- LÖVE callbacks
function InputManager:joystickadded(joystick)
  -- Assign to lowest free player slot (1, 2, 3...)
end

function InputManager:joystickremoved(joystick)
  -- Clear joystick from slot, keep keyboardMap for fallback
end

-- Query API
function InputManager:isDown(playerIndex, action)      -- held this frame
function InputManager:wasPressed(playerIndex, action)  -- edge: false->true
function InputManager:wasReleased(playerIndex, action) -- edge: true->false

-- Config
function InputManager:setDeadzone(playerIndex, deadzone)
function InputManager:getAssignedJoystick(playerIndex)
```

---

## 4. Action Mappings

### 4.1 Keyboard (per player, `action_map.lua`)

```lua
local KEYBOARD_MAPS = {
  [1] = {left='left', right='right', up='up', down='down', use='rshift', start='escape', back='tab'},
  [2] = {left='a', right='d', up='w', down='s', use='q', start='escape', back='tab'},
  -- P3+ = no keyboard defaults
}
```

### 4.2 Gamepad (standard layout)

| Action | Buttons | Axes |
|--------|---------|------|
| `left` | D-pad Left | Left Stick X < -deadzone |
| `right` | D-pad Right | Left Stick X > deadzone |
| `up` | D-pad Up | Left Stick Y < -deadzone |
| `down` | D-pad Down | Left Stick Y > deadzone |
| `use` | A, B | — |
| `start` | Start | — |
| `back` | Back, Guide | — |

- Deadzone default: `0.2` (configurable per player)
- Supports both `Gamepad` (standard) and generic `Joystick` (axis 1/2) modes
- D-pad and left stick are ORed together

---

## 5. Integration Points

### 5.1 `src/main.lua`

```lua
-- In Game:init()
inputManager = InputManager:new()

function love.joystickadded(joystick)
  inputManager:joystickadded(joystick)
end

function love.joystickremoved(joystick)
  inputManager:joystickremoved(joystick)
end

function love.update(dt)
  inputManager:update(dt)
  -- ... existing update
end
```

### 5.2 `src/player/player.lua`

```lua
function Player:isDown(action)
  return inputManager:isDown(self.index, action)
end
```

### 5.3 `src/ui/map_list.lua`

- Replace `joystick.getJoysticks()[1]` polling with `inputManager:isDown(1, 'left')` / `'right'`
- Keep `gamepadpressed`/`joystickpressed` for menu actions (start/back)

### 5.4 `src/game_states.lua`

- `MenuState`: Use `inputManager:wasPressed(1, 'start')` etc.
- `GameOverState`: Use `inputManager` for all players
- Remove direct `love.keyboard.isDown` / `love.joystick` calls

---

## 6. Hotplug Behavior

| Event | Behavior |
|-------|----------|
| Controller connected | Assigned to lowest free slot (1→2→3...). Keyboard remains as fallback. |
| Controller disconnected | Slot freed. Keyboard mapping preserved. Player can continue on keyboard. |
| Multiple controllers | Each gets unique slot. P1 keyboard + controller both work (OR logic). |

---

## 7. Testing Strategy

### 7.1 Unit Tests (`tests/unit/input_manager_test.lua`)

- Mock `love.joystick` with fake joystick objects
- Verify keyboard mapping for P1/P2
- Verify gamepad axis → action mapping (deadzone handling)
- Verify gamepad button → action mapping
- Verify `wasPressed`/`wasReleased` edge detection
- Verify hotplug: add/remove joystick updates slots correctly

### 7.2 Integration Tests (`tests/integration/gamepad_test.lua`)

- Start game with real LÖVE, simulate `joystickadded` event
- Verify player can move/jump using gamepad in sandbox map
- Verify menu navigation works with gamepad
- Test 2 controllers simultaneously

### 7.3 E2E (Manual)

- `love . ipc map=sandbox` with controller connected
- Verify both players work on keyboard + gamepad simultaneously

---

## 8. Assets Required

- `res/gamecontrollerdb.txt` — SDL_GameControllerDB mappings (standard community file)

---

## 9. Scope & Non-Goals

**In Scope:**
- 2+ player gamepad support with hotplug
- Unified keyboard + gamepad input
- Edge detection (pressed/released)
- Menu navigation via gamepad
- Configurable deadzone

**Out of Scope:**
- Button remapping UI (future)
- Haptic feedback (future)
- Touch/mobile input
- Steam Input / platform-specific APIs

---

## 10. Migration Notes

- Existing `Player:isDown()` logic removed, replaced with delegation
- `map_list.lua` direct joystick polling removed
- `game_states.lua` direct keyboard/joystick checks removed
- IPC tools (`fido-kitch-ipc.ts`) unchanged — they inject keyboard actions which still work via `love.keyboard.isDown` override in `ipc/game_api.lua`

---

## 11. Rollout Plan

1. Create `src/input/` module with tests
2. Integrate in `main.lua`
3. Refactor `player.lua`
4. Refactor `map_list.lua`
5. Refactor `game_states.lua`
5. Run `./test-all.sh`
6. Manual verification with controller