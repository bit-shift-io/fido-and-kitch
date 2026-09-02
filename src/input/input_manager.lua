local Class = require("lib.hump.class")
local actionMap = require("src.input.action_map")
local InputConfig = require("src.input.input_config")
local Log = require("src.utils.log")

local InputManager = Class({})

function InputManager:init()
	if love and love.joystick and love.joystick.loadGamepadMappings then
		Log.info("[InputManager] Loading gamecontrollerdb.txt")
		local success, err = love.joystick.loadGamepadMappings("res/gamecontrollerdb.txt")
		Log.info("[InputManager] loadGamepadMappings:", success, err)
	end

	-- Load persistent input configuration
	self.config = InputConfig:new()

	self.players = {}
	self.actionState = {}
	self.prevActionState = {}
	for i = 1, 4 do
		self:ensurePlayer(i)
	end

	-- Handle already-connected joysticks (joystickadded doesn't fire for already-connected)
	if love and love.joystick then
		local joysticks = love.joystick.getJoysticks()
		Log.info("[InputManager] Found", #joysticks, "already-connected joystick(s)")
		for _, js in ipairs(joysticks) do
			self:joystickadded(js)
		end
	end
end

function InputManager:ensurePlayer(idx)
	if not self.players[idx] then
		local km = self.config:getKeyboardMap(idx)
		self.players[idx] = { joystick = nil, deadzone = self.config:getDeadzone(idx), keyboardMap = km }
	end
	if not self.actionState[idx] then
		self.actionState[idx] = {}
	end
	if not self.prevActionState[idx] then
		self.prevActionState[idx] = {}
	end
end

local function copyActionState(actionState)
	local copy = {}
	for i, s in pairs(actionState) do
		copy[i] = {}
		for a, v in pairs(s) do
			copy[i][a] = v
		end
	end
	return copy
end

-- Swallow the edges of whatever is currently held, so the next update() sees
-- no newly-pressed actions.
--
-- Game:setGameState calls this because one physical press must not be acted on
-- twice. love.keypressed runs in the event phase, before update() has polled
-- the keyboard: a press handled there (MenuState starting a map on Enter) would
-- still be held when update() runs, and `return` is also player 1's `start`
-- action -- which InGameState reads as "leave the map". Without this the map
-- would load and unload again inside a single frame.
function InputManager:swallowEdges()
	self.swallowNextEdges = true
end

function InputManager:update(dt)
	self.prevActionState = copyActionState(self.actionState)
	self.actionState = {}

	for i = 1, 4 do
		self:ensurePlayer(i)
	end

	for i, p in ipairs(self.players) do
		self.actionState[i] = {}

		local km = p.keyboardMap
		if love and love.keyboard then
			for action, key in pairs(km) do
				if love.keyboard.isDown(key) then
					self.actionState[i][action] = true
				end
			end
		end

		if p.joystick then
			self:pollGamepad(i, p)
		end
	end

	-- Treat everything held this frame as already-seen, so wasPressed reports
	-- nothing until a key is genuinely released and pressed again.
	if self.swallowNextEdges then
		self.swallowNextEdges = false
		self.prevActionState = copyActionState(self.actionState)
	end
end

function InputManager:pollGamepad(idx, player)
	local js = player.joystick
	if not js or not js:isConnected() then
		return
	end
	local dz = player.deadzone

	-- Always check raw axes first (works for both gamepad and generic joystick)
	local hx = js:getAxis(1) or 0
	local hy = js:getAxis(2) or 0

	-- If it's a gamepad, also check gamepad axes as fallback
	if js:isGamepad() then
		local gx = js:getGamepadAxis("leftx") or 0
		local gy = js:getGamepadAxis("lefty") or 0
		-- Use gamepad axes if they have meaningful values, otherwise use raw
		if gx ~= 0 or gy ~= 0 then
			hx, hy = gx, gy
		end
	end

	if hx < -dz then
		self.actionState[idx].left = true
	end
	if hx > dz then
		self.actionState[idx].right = true
	end
	if hy < -dz then
		self.actionState[idx].up = true
	end
	if hy > dz then
		self.actionState[idx].down = true
	end

	-- Check buttons: try gamepad buttons first, then raw button indices
	local isGamepad = js:isGamepad()
	local gamepadButtons = actionMap.GAMEPAD_BUTTONS
	local joystickButtons = actionMap.JOYSTICK_BUTTONS

	for action, _ in pairs({ use = true, start = true, back = true }) do
		local isDown = false
		-- Try gamepad buttons
		if isGamepad then
			for _, btn in ipairs(gamepadButtons[action] or {}) do
				if js.isGamepadDown and js:isGamepadDown(btn) then
					isDown = true
					break
				end
			end
		end
		-- Fallback to raw button indices
		if not isDown then
			for _, btn in ipairs(joystickButtons[action] or {}) do
				if js:isDown(btn) then
					isDown = true
					break
				end
			end
		end
		if isDown then
			self.actionState[idx][action] = true
		end
	end
end

function InputManager:joystickadded(joystick)
	Log.info("[InputManager] joystickadded:", joystick:getName(), "isGamepad:", joystick:isGamepad())
	for i = 1, 4 do
		if not self.players[i].joystick then
			self.players[i].joystick = joystick

			-- Apply saved forced non-gamepad preference
			if self.config:isForcedNonGamepad(i) then
				self.forcedNonGamepad = self.forcedNonGamepad or {}
				self.forcedNonGamepad[joystick] = true
				Log.info("[InputManager] Applied forced non-gamepad mode for player", i)
			end

			Log.info("[InputManager] Assigned joystick to player", i)
			break
		end
	end
end

function InputManager:joystickremoved(joystick)
	Log.info("[InputManager] joystickremoved:", joystick:getName())
	for i = 1, 4 do
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

return InputManager
