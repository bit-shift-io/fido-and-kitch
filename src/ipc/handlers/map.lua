local GameAPI = {}

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

function GameAPI.loadMap(mapName)
	if not mapName then
		return nil, 'Map name required'
	end
	
	if not game or not game.fsm then
		return nil, 'Game not loaded'
	end
	
	local Map = require('src.map')
	local mapPath = Map.resolveMapFile('res/map/' .. mapName)
	
	game:setGameState('InGameState')
	game:load{map = mapPath}
	
	return 'OK: Loaded ' .. mapName
end

function GameAPI.restartLevel()
	local state, err = inGameState()
	if not state then
		return nil, err
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

function GameAPI.getTileGrid()
	if not map or not map.map then
		return nil, 'No map loaded'
	end
	
	local json = require('lib.dkjson')
	local tileWidth = map.map.tilewidth
	local tileHeight = map.map.tileheight
	local mapWidth = map.map.width
	local mapHeight = map.map.height
	
	local grid = {}
	for y = 1, mapHeight do
		grid[y] = {}
		for x = 1, mapWidth do
			grid[y][x] = 0
		end
	end
	
	for _, layer in ipairs(map.map.layers) do
		if layer.type == 'tilelayer' and layer.data then
			for y, row in pairs(layer.data) do
				for x, cell in pairs(row) do
					if cell and cell.gid and cell.gid > 0 then
						grid[y][x] = 1
					end
				end
			end
		end
	end
	
	local function markLadders(grid, objects, tileWidth, tileHeight)
		for _, obj in ipairs(objects) do
			if obj.type == 'ladder' then
				local topY  = obj.y - (obj.height or 0)
				local tileX = math.floor(obj.x / tileWidth) + 1
				for ty = math.floor(topY / tileHeight) + 1, math.floor(obj.y / tileHeight) do
					if grid[ty] and grid[ty][tileX] then
						grid[ty][tileX] = 2
					end
				end
			end
		end
	end
	
	local function markKillzones(grid, objects, tileWidth, tileHeight)
		for _, obj in ipairs(objects) do
			if obj.properties and obj.properties.killzone then
				local tileX = math.floor(obj.x / tileWidth) + 1
				local tileY = math.floor(obj.y / tileHeight) + 1
				if grid[tileY] and grid[tileY][tileX] then
					grid[tileY][tileX] = 3
				end
			end
		end
	end
	
	for _, layer in ipairs(map.map.layers) do
		if layer.type == 'objectgroup' and layer.objects then
			markLadders(grid, layer.objects, tileWidth, tileHeight)
			markKillzones(grid, layer.objects, tileWidth, tileHeight)
		end
	end
	
	return json.encode({ok = true, grid = grid, width = mapWidth, height = mapHeight})
end

return GameAPI