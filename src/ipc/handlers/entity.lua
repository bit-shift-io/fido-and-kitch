local GameAPI = {}
local json = require('lib.dkjson')

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

local function serializeMapEntity(entity)
	if entity.type == 'player' then return nil end
	if entity.type == 'drawbridge' then return getDrawbridgeInfo(entity) end

	local info = getEntityBaseInfo(entity)
	if not info then return nil end
	if entity.state then      info.entityState = entity.state end
	if entity.itemName then   info.itemName    = entity.itemName end
	if entity.isLadder then   info.isLadder    = true end
	if entity.isKillZone then
		info.isKillZone = true
		info.deathType  = entity.deathType
	end
	return info
end

local function getEntityBaseInfo(entity)
	if not entity then return nil end
	local info = {
		type = entity.type or 'unknown',
		name = entity.name or entity.type or 'unnamed',
	}
	
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
	
	info.collider = getColliderInfo(entity.collider)
	info.hasCollider = entity.collider ~= nil
	
	return info
end

local function getPlayerInfo(player, index)
	local base = getEntityBaseInfo(player)
	base.type = 'player'
	base.name = 'player'
	base.index = index
	
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
	base.collider = getColliderInfo(entity.deck)
	return base
end

function GameAPI.getEntities()
	local state, err = inGameState()
	if not state then
		return nil, err
	end

	local entities = {}
	
	if state.players then
		for i, player in ipairs(state.players) do
			table.insert(entities, getPlayerInfo(player, i))
		end
	end
	
	if map and map.layers then
		for _, layer in ipairs(map.layers) do
			if layer.entities then
				for _, entity in ipairs(layer.entities) do
					if entity and not entity.remove_from_map_flag then
						local info = serializeMapEntity(entity)
						if info then
							table.insert(entities, info)
						end
					end
				end
			end
		end
	end

	local result = {
		ok = true,
		count = #entities,
		entities = entities
	}
	return json.encode(result)
end

function GameAPI.spawnEntity(entityType, x, y, props)
	local state, err = inGameState()
	if not state then
		return nil, err
	end

	if not map or not map.layers then
		return nil, 'No map loaded'
	end
	
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
	
	local entity = map:loadEntity(entityType, targetLayer, mockObject)
	
	if not entity then
		return nil, 'Failed to spawn entity: ' .. entityType
	end
	
	return 'OK: Spawned ' .. entityType .. ' at ' .. x .. ',' .. y
end

function GameAPI.getState()
	local state, err = inGameState()
	if not state then
		return nil, err
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
		mapName = mapName:match('([^/]+)%.tmj$') or mapName
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

return GameAPI