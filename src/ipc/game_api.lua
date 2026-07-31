local GameAPI = {}

-- Input injection system (simulates player keyboard input)
local injectedInput = {
	p1 = {},
	p2 = {}
}

-- Override love.keyboard.isDown to check injected input
local overrideInstalled = false

local function installOverride()
    if overrideInstalled then return end
    overrideInstalled = true
    local originalIsDown = _G.love and _G.love.keyboard and _G.love.keyboard.isDown or function() return false end
    function _G.love.keyboard.isDown(key)
        -- Check P1 injected input
        for action, down in pairs(injectedInput.p1) do
            local p1Keys = {left='left', right='right', up='up', down='down', use='rshift'}
            if p1Keys[action] == key and down then
                return true
            end
        end
        -- Check P2 injected input
        for action, down in pairs(injectedInput.p2) do
            local p2Keys = {left='a', right='d', up='w', down='s', use='q'}
            if p2Keys[action] == key and down then
                return true
            end
        end
        return originalIsDown(key)
    end
end

-- Ensure override is installed when needed
local function ensureOverride()
    if not overrideInstalled and _G.love and _G.love.keyboard then
        installOverride()
    end
end

function GameAPI.injectInput(playerIdx, action, down)
	ensureOverride()
	local keys = {}
	if playerIdx == 1 then
		keys = {
			left = 'left', right = 'right', up = 'up', down = 'down', use = 'rshift'
		}
		injectedInput.p1[action] = down
	else
		keys = {
			left = 'a', right = 'd', up = 'w', down = 's', use = 'q'
		}
		injectedInput.p2[action] = down
	end
	return 'OK: Injected ' .. action .. '=' .. (down and 'down' or 'up') .. ' for player ' .. playerIdx
end

function GameAPI.injectKey(playerIdx, key, down)
	if playerIdx == 1 then
		injectedInput.p1[key] = down
	else
		injectedInput.p2[key] = down
	end
	return 'OK: Injected key ' .. key .. '=' .. (down and 'down' or 'up') .. ' for player ' .. playerIdx
end

function GameAPI.getInjectedInput()
	return injectedInput
end

function GameAPI.holdKey(playerIdx, action, duration)
	-- Press the key
	GameAPI.injectInput(playerIdx, action, true)
	
	-- Step frames for the duration (60 fps)
	local frames = math.floor(duration * 60)
	for i = 1, frames do
		if game and game.fsm and game.fsm.currentState then
			if inputManager and inputManager.update then
				inputManager:update(1/60)
			end
			game.fsm.currentState:update(1/60)
			if world and world.update then
				world:update(1/60)
			end
		end
	end
	
	-- Release the key
	GameAPI.injectInput(playerIdx, action, false)
	
	return 'OK: Held ' .. action .. ' for player ' .. playerIdx .. ' for ' .. duration .. 's'
end

function GameAPI.resize(w, h)
	if not _G.love or not _G.love.window then
		return nil, 'love.window not available'
	end
	_G.love.window.setMode(w, h)
	return 'OK: Resized to ' .. w .. 'x' .. h
end

function GameAPI.movePlayer(idx, dx, dy)
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not in a playable state'
	end

	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game (current state: ' .. (state.__class and state.__class.name or 'unknown') .. ')'
	end

	local players = state.players
	if not players or not players[idx] then
		return nil, 'Player ' .. idx .. ' not found'
	end

	local player = players[idx]
	if player.collider and player.collider.getPositionV and player.collider.setPositionV then
		local pos = player.collider:getPositionV()
		local Vector = require('lib.hump.vector')
		player.collider:setPositionV(Vector(pos.x + dx, pos.y + dy))
		local newPos = player.collider:getPositionV()
		return 'OK: Player ' .. idx .. ' at ' .. math.floor(newPos.x) .. ',' .. math.floor(newPos.y)
	end

	return nil, 'Player does not have collider with position methods'
end

function GameAPI.getState()
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end

	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end

	local players = state.players
	if not players or #players < 2 then
		return nil, 'Players not found'
	end

	local p1 = players[1]
	local p2 = players[2]

	local w = _G.love.graphics.getWidth()
	local h = _G.love.graphics.getHeight()

	local mapName = state.currentMap or 'unknown'
	if type(mapName) == 'string' then
		mapName = mapName:match('([^/]+)%.tmx$') or mapName
	end

	local p1Pos = p1.collider and p1.collider.getPositionV and p1.collider:getPositionV()
	local p2Pos = p2.collider and p2.collider.getPositionV and p2.collider:getPositionV()

	if not p1Pos or not p2Pos then
		return nil, 'Cannot get player positions'
	end

	return 'OK: p1x=' .. math.floor(p1Pos.x) .. ' p1y=' .. math.floor(p1Pos.y)
		.. ' p2x=' .. math.floor(p2Pos.x) .. ' p2y=' .. math.floor(p2Pos.y)
		.. ' w=' .. w .. ' h=' .. h .. ' map=' .. mapName
end

function GameAPI.getPlayerPos(idx)
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end

	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end

	local players = state.players
	if not players or not players[idx] then
		return nil, 'Player ' .. idx .. ' not found'
	end

	local player = players[idx]
	local pos = player.collider and player.collider.getPositionV and player.collider:getPositionV()
	if not pos then
		return nil, 'Cannot get player position'
	end

	return 'OK: Player ' .. idx .. ' at ' .. math.floor(pos.x) .. ',' .. math.floor(pos.y)
end

function GameAPI.restartLevel()
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end

	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end

	local map = state.currentMap
	if not map then
		return nil, 'No current map to restart'
	end

	game:setGameState('InGameState')
	game:load{map = map}
	return 'OK: Level restarted'
end

function GameAPI.goToMenu()
	if not game or not game.fsm then
		return nil, 'Game not loaded'
	end

	game:setGameState('MenuState')
	return 'OK: Returned to menu'
end

function GameAPI.setJoystickNonGamepad(idx, forced)
	if not inputManager then
		return nil, 'InputManager not available'
	end
	
	-- Store the preference in InputManager to apply when joystick is assigned
	inputManager.forcedNonGamepadPreferences = inputManager.forcedNonGamepadPreferences or {}
	inputManager.forcedNonGamepadPreferences[idx] = forced
	
	-- If joystick is already assigned, apply immediately
	if inputManager.players[idx] and inputManager.players[idx].joystick then
		inputManager.forcedNonGamepad = inputManager.forcedNonGamepad or {}
		inputManager.forcedNonGamepad[inputManager.players[idx].joystick] = forced
	end
	
	return 'OK: Player ' .. idx .. ' joystick forced to non-gamepad mode: ' .. tostring(forced)
end

function GameAPI.toggleCamera()
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end

	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end

	if state.camera and state.camera.toggleOverview then
		state.camera:toggleOverview()
		return 'OK: Camera overview toggled'
	end

	return nil, 'Camera not available'
end

return GameAPI