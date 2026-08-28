local GameAPI = {}
local ActionMap = require('src.input.action_map')

local P1_KEYS = ActionMap.KEYBOARD_MAPS[1]
local P2_KEYS = ActionMap.KEYBOARD_MAPS[2]

local FRAME_DT = 1 / 60
local function stepFixed(frames)
	for _ = 1, frames do
		if game and game.fsm and game.fsm.currentState then
			if inputManager and inputManager.update then
				inputManager:update(FRAME_DT)
			end
			game.fsm.currentState:update(FRAME_DT)
		end
	end
end

local function inGameState()
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end

	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end

	return state
end

local injectedInput = {
	p1 = {},
	p2 = {}
}

local overrideInstalled = false

local function installOverride()
    if overrideInstalled then return end
    overrideInstalled = true
    local originalIsDown = _G.love and _G.love.keyboard and _G.love.keyboard.isDown or function() return false end
    function _G.love.keyboard.isDown(key)
        for action, down in pairs(injectedInput.p1) do
            if P1_KEYS[action] == key and down then
                return true
            end
        end
        for action, down in pairs(injectedInput.p2) do
            if P2_KEYS[action] == key and down then
                return true
            end
        end
        return originalIsDown(key)
    end
end

local function ensureOverride()
    if not overrideInstalled and _G.love and _G.love.keyboard then
        installOverride()
    end
end

function GameAPI.injectInput(playerIdx, action, down)
	ensureOverride()
	if playerIdx == 1 then
		injectedInput.p1[action] = down
	else
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

function GameAPI.holdKey(playerIdx, action, duration)
	GameAPI.injectInput(playerIdx, action, true)
	stepFixed(math.floor(duration * 60))
	GameAPI.injectInput(playerIdx, action, false)
	return 'OK: Held ' .. action .. ' for player ' .. playerIdx .. ' for ' .. duration .. 's'
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

function GameAPI.getPlayerPos(idx)
	local state, err = inGameState()
	if not state then
		return nil, err
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

function GameAPI.setJoystickNonGamepad(idx, forced)
	if not inputManager then
		return nil, 'InputManager not available'
	end
	
	inputManager.forcedNonGamepadPreferences = inputManager.forcedNonGamepadPreferences or {}
	inputManager.forcedNonGamepadPreferences[idx] = forced
	
	if inputManager.players[idx] and inputManager.players[idx].joystick then
		inputManager.forcedNonGamepad = inputManager.forcedNonGamepad or {}
		inputManager.forcedNonGamepad[inputManager.players[idx].joystick] = forced
	end
	
	return 'OK: Player ' .. idx .. ' joystick forced to non-gamepad mode: ' .. tostring(forced)
end

return GameAPI