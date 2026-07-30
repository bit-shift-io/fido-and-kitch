local Class = require('lib.hump.class')

local CommandHandler = Class{}

function CommandHandler:init(gameAPI)
	self.gameAPI = gameAPI
	self.commands = {}
	self:registerBuiltins()
end

function CommandHandler:registerBuiltins()
	self:register('RESIZE', function(args)
		if #args ~= 2 then return nil, 'Usage: RESIZE <width> <height>' end
		local w, h = tonumber(args[1]), tonumber(args[2])
		if not w or not h then return nil, 'Width and height must be numbers' end
		return self.gameAPI.resize(w, h)
	end)

	self:register('MOVE_PLAYER', function(args)
		if #args ~= 3 then return nil, 'Usage: MOVE_PLAYER <1|2> <dx> <dy>' end
		local idx, dx, dy = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
		if not idx or not dx or not dy then return nil, 'All arguments must be numbers' end
		if idx ~= 1 and idx ~= 2 then return nil, 'Player index must be 1 or 2' end
		return self.gameAPI.movePlayer(idx, dx, dy)
	end)

	self:register('GET_STATE', function(args)
		if #args ~= 0 then return nil, 'Usage: GET_STATE (no arguments)' end
		return self.gameAPI.getState()
	end)

	self:register('GET_PLAYER_POS', function(args)
		if #args ~= 1 then return nil, 'Usage: GET_PLAYER_POS <1|2>' end
		local idx = tonumber(args[1])
		if not idx or (idx ~= 1 and idx ~= 2) then return nil, 'Player index must be 1 or 2' end
		return self.gameAPI.getPlayerPos(idx)
	end)

	self:register('RESTART_LEVEL', function(args)
		if #args ~= 0 then return nil, 'Usage: RESTART_LEVEL (no arguments)' end
		return self.gameAPI.restartLevel()
	end)

	self:register('MENU', function(args)
		if #args ~= 0 then return nil, 'Usage: MENU (no arguments)' end
		return self.gameAPI.goToMenu()
	end)

	self:register('INPUT', function(args)
		if #args ~= 3 then return nil, 'Usage: INPUT <1|2> <left|right|up|down|use> <down|up>' end
		local idx = tonumber(args[1])
		if not idx or (idx ~= 1 and idx ~= 2) then return nil, 'Player index must be 1 or 2' end
		local action = args[2]:lower()
		local validActions = {left=true, right=true, up=true, down=true, use=true}
		if not validActions[action] then return nil, 'Action must be: left, right, up, down, or use' end
		local down = args[3]:lower() == 'down'
		return self.gameAPI.injectInput(idx, action, down)
	end)

	self:register('KEY', function(args)
		if #args ~= 3 then return nil, 'Usage: KEY <1|2> <key> <down|up>' end
		local idx = tonumber(args[1])
		if not idx or (idx ~= 1 and idx ~= 2) then return nil, 'Player index must be 1 or 2' end
		local key = args[2]
		local down = args[3]:lower() == 'down'
		return self.gameAPI.injectKey(idx, key, down)
	end)

	self:register('PRESS_KEY', function(args)
		if #args ~= 2 then return nil, 'Usage: PRESS_KEY <1|2> <left|right|up|down|use>' end
		local idx = tonumber(args[1])
		if not idx or (idx ~= 1 and idx ~= 2) then return nil, 'Player index must be 1 or 2' end
		local action = args[2]:lower()
		local validActions = {left=true, right=true, up=true, down=true, use=true}
		if not validActions[action] then return nil, 'Action must be: left, right, up, down, or use' end
		return self.gameAPI.injectInput(idx, action, true)
	end)

	self:register('RELEASE_KEY', function(args)
		if #args ~= 2 then return nil, 'Usage: RELEASE_KEY <1|2> <left|right|up|down|use>' end
		local idx = tonumber(args[1])
		if not idx or (idx ~= 1 and idx ~= 2) then return nil, 'Player index must be 1 or 2' end
		local action = args[2]:lower()
		local validActions = {left=true, right=true, up=true, down=true, use=true}
		if not validActions[action] then return nil, 'Action must be: left, right, up, down, or use' end
		return self.gameAPI.injectInput(idx, action, false)
	end)

	self:register('HOLD_KEY', function(args)
		if #args ~= 3 then return nil, 'Usage: HOLD_KEY <1|2> <left|right|up|down|use> <duration>' end
		local idx = tonumber(args[1])
		if not idx or (idx ~= 1 and idx ~= 2) then return nil, 'Player index must be 1 or 2' end
		local action = args[2]:lower()
		local validActions = {left=true, right=true, up=true, down=true, use=true}
		if not validActions[action] then return nil, 'Action must be: left, right, up, down, or use' end
		local duration = tonumber(args[3])
		if not duration or duration <= 0 then return nil, 'Duration must be a positive number' end
		return self.gameAPI.holdKey(idx, action, duration)
	end)

	self:register('TOGGLE_CAMERA', function(args)
		if #args ~= 0 then return nil, 'Usage: TOGGLE_CAMERA (no arguments)' end
		return self.gameAPI.toggleCamera()
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