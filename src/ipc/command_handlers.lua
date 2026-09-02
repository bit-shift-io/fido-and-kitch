local Class = require('lib.hump.class')

-- Map gamepad button names to game actions
local GAMEPAD_BUTTON_MAP = {
	a = 'use',
	b = 'use',
	start = 'start',
	back = 'back',
	guide = 'back',
}

local VALID_ACTIONS = {left = true, right = true, up = true, down = true, use = true, start = true, back = true}

local function resolveAction(action)
	return GAMEPAD_BUTTON_MAP[action] or action
end

local function validateAction(action)
	return VALID_ACTIONS[action] ~= nil
end

-- Validates that exactly `n` args were supplied; returns nil+usage-msg otherwise.
local function requireArgc(args, n, usage)
	if #args ~= n then return nil, 'Usage: ' .. usage end
	return true
end

-- Validates a 1-based player index arg; returns the index or nil+error.
local function playerIndex(args, i)
	local idx = tonumber(args[i])
	if not idx or (idx ~= 1 and idx ~= 2) then return nil, 'Player index must be 1 or 2' end
	return idx
end

-- Resolves a raw action token and validates it; returns the action or nil+error.
local function resolveValidatedAction(raw)
	local action = resolveAction(raw:lower())
	if not validateAction(action) then return nil, 'Action must be: left, right, up, down, use, start, back, a, or b' end
	return action
end

-- Coerces a numeric arg; returns the number or nil+error.
local function numberArg(args, i, label)
	local n = tonumber(args[i])
	if not n then return nil, label .. ' must be a number' end
	return n
end

local CommandHandler = Class{}

function CommandHandler:init(gameAPI)
	self.gameAPI = gameAPI
	self.commands = {}
	self:registerBuiltins()
end

function CommandHandler:registerBuiltins()
	self:registerInfoCommands()
	self:registerPlayerCommands()
	self:registerActionCommands()
	self:registerControlCommands()
end

-- Read-only state/query commands with no arguments.
function CommandHandler:registerInfoCommands()
	self:register('GET_STATE', function(args)
		if not requireArgc(args, 0, 'GET_STATE (no arguments)') then return nil, 'Usage: GET_STATE (no arguments)' end
		return self.gameAPI.getState()
	end)

	self:register('GET_ENTITIES', function(args)
		if not requireArgc(args, 0, 'GET_ENTITIES (no arguments)') then return nil, 'Usage: GET_ENTITIES (no arguments)' end
		return self.gameAPI.getEntities()
	end)

	self:register('GET_TILE_GRID', function(args)
		if not requireArgc(args, 0, 'GET_TILE_GRID (no arguments)') then return nil, 'Usage: GET_TILE_GRID (no arguments)' end
		return self.gameAPI.getTileGrid()
	end)

	self:register('TOGGLE_DEBUG_DRAW', function(args)
		if not requireArgc(args, 0, 'TOGGLE_DEBUG_DRAW (no arguments)') then return nil, 'Usage: TOGGLE_DEBUG_DRAW (no arguments)' end
		return self.gameAPI.toggleDebugDraw()
	end)

	self:register('RESTART_LEVEL', function(args)
		if not requireArgc(args, 0, 'RESTART_LEVEL (no arguments)') then return nil, 'Usage: RESTART_LEVEL (no arguments)' end
		return self.gameAPI.restartLevel()
	end)

	self:register('MENU', function(args)
		if not requireArgc(args, 0, 'MENU (no arguments)') then return nil, 'Usage: MENU (no arguments)' end
		return self.gameAPI.goToMenu()
	end)

	self:register('TOGGLE_CAMERA', function(args)
		if not requireArgc(args, 0, 'TOGGLE_CAMERA (no arguments)') then return nil, 'Usage: TOGGLE_CAMERA (no arguments)' end
		return self.gameAPI.toggleCamera()
	end)

	self:register('GET_LOG', function(args)
		if not _ipc_log then return nil, 'Log buffer not available' end
		local count = numberArg(args, 1, 'Count')
		local lines
		if count then
			local start = math.max(1, #_ipc_log - count + 1)
			lines = {}
			for i = start, #_ipc_log do
				lines[#lines + 1] = _ipc_log[i]
			end
		else
			lines = _ipc_log
		end
		return table.concat(lines, '\n')
	end)
end

-- Commands that manipulate a specific player by index.
function CommandHandler:registerPlayerCommands()
	self:register('MOVE_PLAYER', function(args)
		if not requireArgc(args, 3, 'MOVE_PLAYER <1|2> <dx> <dy>') then return nil, 'Usage: MOVE_PLAYER <1|2> <dx> <dy>' end
		local idx = assert(playerIndex(args, 1))
		local dx, dy = numberArg(args, 2, 'dx'), numberArg(args, 3, 'dy')
		if not dx or not dy then return nil, 'All arguments must be numbers' end
		return self.gameAPI.movePlayer(idx, dx, dy)
	end)

	self:register('GET_PLAYER_POS', function(args)
		if not requireArgc(args, 1, 'GET_PLAYER_POS <1|2>') then return nil, 'Usage: GET_PLAYER_POS <1|2>' end
		local idx = assert(playerIndex(args, 1))
		return self.gameAPI.getPlayerPos(idx)
	end)

	self:register('SET_JOYSTICK_NON_GAMEPAD', function(args)
		if not requireArgc(args, 2, 'SET_JOYSTICK_NON_GAMEPAD <1|2> <true|false>') then return nil, 'Usage: SET_JOYSTICK_NON_GAMEPAD <1|2> <true|false>' end
		local idx = assert(playerIndex(args, 1))
		local forced = args[2]:lower() == 'true'
		return self.gameAPI.setJoystickNonGamepad(idx, forced)
	end)
end

-- Commands that inject action/keyboard input into a player.
function CommandHandler:registerActionCommands()
	self:register('INPUT', function(args)
		if not requireArgc(args, 3, 'INPUT <1|2> <left|right|up|down|use|start|back|a|b> <down|up>') then return nil, 'Usage: INPUT <1|2> <left|right|up|down|use|start|back|a|b> <down|up>' end
		local idx = assert(playerIndex(args, 1))
		local action = assert(resolveValidatedAction(args[2]))
		local down = args[3]:lower() == 'down'
		return self.gameAPI.injectInput(idx, action, down)
	end)

	self:register('KEY', function(args)
		if not requireArgc(args, 3, 'KEY <1|2> <key> <down|up>') then return nil, 'Usage: KEY <1|2> <key> <down|up>' end
		local idx = assert(playerIndex(args, 1))
		local key = args[2]
		local down = args[3]:lower() == 'down'
		return self.gameAPI.injectKey(idx, key, down)
	end)

	self:register('PRESS_KEY', function(args)
		if not requireArgc(args, 2, 'PRESS_KEY <1|2> <left|right|up|down|use|start|back|a|b>') then return nil, 'Usage: PRESS_KEY <1|2> <left|right|up|down|use|start|back|a|b>' end
		local idx = assert(playerIndex(args, 1))
		local action = assert(resolveValidatedAction(args[2]))
		return self.gameAPI.injectInput(idx, action, true)
	end)

	self:register('RELEASE_KEY', function(args)
		if not requireArgc(args, 2, 'RELEASE_KEY <1|2> <left|right|up|down|use|start|back|a|b>') then return nil, 'Usage: RELEASE_KEY <1|2> <left|right|up|down|use|start|back|a|b>' end
		local idx = assert(playerIndex(args, 1))
		local action = assert(resolveValidatedAction(args[2]))
		return self.gameAPI.injectInput(idx, action, false)
	end)

	self:register('HOLD_KEY', function(args)
		if not requireArgc(args, 3, 'HOLD_KEY <1|2> <left|right|up|down|use|start|back|a|b> <duration>') then return nil, 'Usage: HOLD_KEY <1|2> <left|right|up|down|use|start|back|a|b> <duration>' end
		local idx = assert(playerIndex(args, 1))
		local action = assert(resolveValidatedAction(args[2]))
		local duration = numberArg(args, 3, 'duration')
		if not duration or duration <= 0 then return nil, 'Duration must be a positive number' end
		return self.gameAPI.holdKey(idx, action, duration)
	end)
end

-- Commands for window/level/entity control.
function CommandHandler:registerControlCommands()
	self:register('RESIZE', function(args)
		if not requireArgc(args, 2, 'RESIZE <width> <height>') then return nil, 'Usage: RESIZE <width> <height>' end
		local w, h = tonumber(args[1]), tonumber(args[2])
		if not w or not h then return nil, 'Width and height must be numbers' end
		return self.gameAPI.resize(w, h)
	end)

	self:register('LOAD_MAP', function(args)
		if #args < 1 then return nil, 'Usage: LOAD_MAP <map_name>' end
		return self.gameAPI.loadMap(args[1])
	end)

	self:register('TAKE_SCREENSHOT', function(args)
		local filename = args[1] or 'screenshot_' .. os.time()
		return self.gameAPI.takeScreenshot(filename)
	end)

	self:register('SPAWN_ENTITY', function(args)
		if #args < 3 then return nil, 'Usage: SPAWN_ENTITY <type> <x> <y> [props_json]' end
		local entityType = args[1]
		local x, y = tonumber(args[2]), tonumber(args[3])
		if not x or not y then return nil, 'x and y must be numbers' end
		local props = {}
		if args[4] then
			local ok, parsed = pcall(require('lib.dkjson').decode, args[4])
			if not ok then return nil, 'Invalid props JSON' end
			props = parsed
		end
		return self.gameAPI.spawnEntity(entityType, x, y, props)
	end)

	self:register('STEP_FRAMES', function(args)
		if not requireArgc(args, 1, 'STEP_FRAMES <count>') then return nil, 'Usage: STEP_FRAMES <count>' end
		local count = tonumber(args[1])
		if not count or count <= 0 then return nil, 'Count must be a positive number' end
		return self.gameAPI.stepFrames(count)
	end)
end

function CommandHandler:register(name, fn)
	self.commands[name:upper()] = fn
end

function CommandHandler:handle(line)
	local parts = {}
	for part in line:gmatch('%S+') do
		table.insert(parts, part)
	end

	if #parts == 0 then
		return 'ERROR: Empty command'
	end

	local cmd = parts[1]:upper()
	local args = {}
	for i = 2, #parts do
		table.insert(args, parts[i])
	end

	local fn = self.commands[cmd]
	if not fn then
		return 'ERROR: Unknown command: ' .. cmd
	end

	local ok, msg, err = pcall(fn, args)
	if not ok then
		return 'ERROR: ' .. msg
	end
	if not msg then
		return 'ERROR: ' .. (err or 'Command failed')
	end

	return msg
end

return CommandHandler