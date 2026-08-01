local GameAPI = {}
local json = require('lib.dkjson')

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

function GameAPI.loadMap(mapName)
	if not mapName then
		return nil, 'Map name required'
	end
	
	if not game or not game.fsm then
		return nil, 'Game not loaded'
	end
	
	local Map = require('src.map')
	local mapPath = Map.resolveMapFile('res/map/' .. mapName)
	
	if game.fsm.currentState and game.fsm.currentState.__class and game.fsm.currentState.__class.name == 'InGameState' then
		game:setGameState('InGameState')
		game:load{map = mapPath}
	else
		game:setGameState('InGameState')
		game:load{map = mapPath}
	end
	
	return 'OK: Loaded ' .. mapName
end

function GameAPI.takeScreenshot(filename)
	if not _G.love or not _G.love.graphics then
		return nil, 'love.graphics not available'
	end
	
	local cwd = love.filesystem.getWorkingDirectory() .. '/' .. filename .. '.png'
	love.filesystem.setIdentity("screenshot_ipc")
	love.graphics.captureScreenshot(cwd)
	
	return 'OK: Screenshot saved to ' .. cwd
end

function GameAPI.getTileGrid()
	if not map or not map.map then
		return nil, 'No map loaded'
	end
	
	local tileWidth = map.map.tilewidth
	local tileHeight = map.map.tileheight
	local mapWidth = map.map.width
	local mapHeight = map.map.height
	
	local grid = {}
	for y = 1, mapHeight do
		grid[y] = {}
		for x = 1, mapWidth do
			grid[y][x] = 0 -- 0 = empty
		end
	end
	
	-- Check tile layers for solid tiles
	for _, layer in ipairs(map.map.layers) do
		if layer.type == 'tilelayer' and layer.data then
			for y, row in pairs(layer.data) do
				for x, cell in pairs(row) do
					if cell and cell.gid and cell.gid > 0 then
						grid[y][x] = 1 -- 1 = solid terrain
					end
				end
			end
		end
	end
	
	-- Check object layers for ladders and killzones
	for _, layer in ipairs(map.map.layers) do
		if layer.type == 'objectgroup' and layer.objects then
			for _, obj in ipairs(layer.objects) do
				if obj.properties then
					local tileX = math.floor(obj.x / tileWidth) + 1
					local tileY = math.floor(obj.y / tileHeight) + 1
					
					if obj.properties.ladder then
						if grid[tileY] and grid[tileY][tileX] then
							grid[tileY][tileX] = 2 -- 2 = ladder
						end
					elseif obj.properties.killzone then
						if grid[tileY] and grid[tileY][tileX] then
							grid[tileY][tileX] = 3 -- 3 = killzone
						end
					end
				end
			end
		end
	end
	
	return json.encode({ok = true, grid = grid, width = mapWidth, height = mapHeight})
end

function GameAPI.spawnEntity(entityType, x, y, props)
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end
	
	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end
	
	if not map or not map.layers then
		return nil, 'No map loaded'
	end
	
	-- Find the first object group layer to add the entity to
	local targetLayer = nil
	for _, layer in ipairs(map.layers) do
		if layer.type == 'objectgroup' and layer.entities then
			targetLayer = layer
			break
		end
	end
	
	if not targetLayer then
		return nil, 'No suitable layer found for entity'
	end
	
	-- Create a mock object for the entity factory
	local mockObject = {
		type = entityType,
		name = entityType,
		x = x,
		y = y,
		width = props.width or 32,
		height = props.height or 32,
		properties = props,
		layer = targetLayer
	}
	
	-- Use the map's entity factory to create the entity
	local entity = map:loadEntity(entityType, targetLayer, mockObject)
	
	if not entity then
		return nil, 'Failed to spawn entity: ' .. entityType
	end
	
	return 'OK: Spawned ' .. entityType .. ' at ' .. x .. ',' .. y
end

function GameAPI.stepFrames(count)
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end
	
	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end
	
	local dt = 1/60
	for i = 1, count do
		if inputManager and inputManager.update then
			inputManager:update(dt)
		end
		if state and state.update then
			state:update(dt)
		end
		if world and world.update then
			world:update(dt)
		end
	end
	
	return 'OK: Stepped ' .. count .. ' frames'
end

local function getColliderInfo(collider)
	if not collider then return nil end
	local bounds = collider.getBounds and collider:getBounds() or nil
	if not bounds then return nil end
	return {
		x = math.floor(bounds.left),
		y = math.floor(bounds.top),
		w = math.floor(bounds.width),
		h = math.floor(bounds.height),
		sensor = collider.isSensor and collider:isSensor() or false,
		walkable = collider.walkable == true,
		bodyType = collider.bodyType or collider.getType and collider:getType() or 'unknown'
	}
end

local function getEntityBaseInfo(entity)
	if not entity then return nil end
	local info = {
		type = entity.type or 'unknown',
		name = entity.name or entity.type or 'unnamed',
	}
	
	-- Position from collider or object
	if entity.collider and entity.collider.getPositionV then
		local pos = entity.collider:getPositionV()
		if entity.collider.getBounds then
			local bounds = entity.collider:getBounds()
			info.x = math.floor(bounds.left)
			info.y = math.floor(bounds.top)
			info.w = math.floor(bounds.width)
			info.h = math.floor(bounds.height)
		else
			info.x = math.floor(pos.x)
			info.y = math.floor(pos.y)
			info.w = 0
			info.h = 0
		end
	elseif entity.object then
		info.x = math.floor(entity.object.x)
		info.y = math.floor(entity.object.y)
		info.w = math.floor(entity.object.width or 0)
		info.h = math.floor(entity.object.height or 0)
	end
	
	-- Collider info
	info.collider = getColliderInfo(entity.collider)
	info.hasCollider = entity.collider ~= nil
	
	return info
end

local function getPlayerInfo(player, index)
	local base = getEntityBaseInfo(player)
	base.type = 'player'
	base.name = 'player'
	base.index = index
	
	-- Player-specific fields
	if player.fsm and player.fsm.currentState then
		base.state = player.fsm.currentState.name or tostring(player.fsm.currentState)
	end
	if player.collider and player.collider.getLinearVelocity then
		local vx, vy = player.collider:getLinearVelocity()
		base.velocity = {x = math.floor(vx or 0), y = math.floor(vy or 0)}
	end
	base.grounded = player.queryFullySupported and player:queryFullySupported() or false
	base.facing = player.facing or 'right'
	base.dead = player.isDead and player:isDead() or false
	
	return base
end

local function getDrawbridgeInfo(entity)
	local base = getEntityBaseInfo(entity)
	if entity.state then
		base.bridgeState = entity.state
	end
	if entity.crossingDirection then
		base.crossingDirection = entity.crossingDirection
	end
	-- Drawbridge has two colliders: deck (walkable) and trigger (sensor)
	base.colliders = {}
	if entity.deck then
		local deckInfo = getColliderInfo(entity.deck)
		if deckInfo then deckInfo.name = 'deck' end
		table.insert(base.colliders, deckInfo)
	end
	if entity.trigger then
		local triggerInfo = getColliderInfo(entity.trigger)
		if triggerInfo then triggerInfo.name = 'trigger' end
		table.insert(base.colliders, triggerInfo)
	end
	base.hasCollider = true
	-- For backward compat, use deck as primary collider
	base.collider = getColliderInfo(entity.deck)
	return base
end

function GameAPI.getEntities()
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end

	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end

	local entities = {}
	
	-- Add players
	if state.players then
		for i, player in ipairs(state.players) do
			table.insert(entities, getPlayerInfo(player, i))
		end
	end
	
	-- Add map entities from layers
	if map and map.layers then
		for _, layer in ipairs(map.layers) do
			if layer.entities then
				for _, entity in ipairs(layer.entities) do
					if entity and not entity.remove_from_map_flag then
						local info = nil
						if entity.type == 'player' then
							-- Already added from state.players
						elseif entity.type == 'drawbridge' then
							info = getDrawbridgeInfo(entity)
						else
							info = getEntityBaseInfo(entity)
							-- Add entity-specific fields
							if entity.state then
								info.entityState = entity.state
							end
							if entity.itemName then
								info.itemName = entity.itemName
							end
							if entity.isLadder then
								info.isLadder = true
							end
							if entity.isKillZone then
								info.isKillZone = true
								info.deathType = entity.deathType
							end
						end
						if info then
							table.insert(entities, info)
						end
					end
				end
			end
		end
	end

	-- Encode to JSON
	local result = {
		ok = true,
		count = #entities,
		entities = entities
	}
	return json.encode(result)
end

return GameAPI