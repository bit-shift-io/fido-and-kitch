-- CLI orchestration: parses flags, builds a level map table, serialises it
-- via TmjWriter, and writes it to res/map/generated/. Kept as a pure,
-- side-effect-free `generate` core (testable without touching the
-- filesystem) plus a thin `run` wrapper that does CLI parsing and file I/O.
local Rng = require('tools.level_generator.rng')
local TmjWriter = require('tools.level_generator.tmj_writer')
local Layout = require('tools.level_generator.layout')
local Plan = require('tools.level_generator.plan')
local Walkthrough = require('tools.level_generator.walkthrough')
local RuleSet = require('tools.level_generator.rule_set')
local Decorate = require('tools.level_generator.decorate')
local Coop = require('tools.level_generator.coop')
local Pushables = require('tools.level_generator.pushables')

local Main = {}

local MAP_WIDTH = 20
local MAP_HEIGHT = 15
local TILE = 32
local GROUND_ROW = MAP_HEIGHT -- 1-indexed: the bottom row

-- Matches res/map/sandbox.tmx's own water tile gids (generic_platformer_tiles.tsx).
local WATER_TILE_GID = 105

local TILESETS = {
	{firstgid = 1, source = '../../editor/tileset_generic_platformer_tiles.tsj'},
}

local function surfaceY(row)
	return (row - 1) * TILE
end

local function spawnObject(id, x, y)
	return {id = id, template = '../../editor/spawn.tj', name = 'spawn', x = x, y = y}
end

local function exitObject(id, x, y, actorCount)
	return {
		id = id,
		template = '../../editor/exit_door.tj',
		name = 'exit_door',
		x = x,
		y = y,
		properties = {{name = 'actor_count', type = 'int', value = actorCount}},
	}
end

local function teleportObject(id, x, y, targetId, enabled)
	local properties = {{name = 'target', type = 'object', value = targetId}}
	if enabled ~= nil then
		table.insert(properties, {name = 'enabled', type = 'bool', value = enabled})
	end
	return {
		id = id,
		template = '../../editor/teleport.tj',
		name = 'teleport',
		type = 'teleport',
		x = x,
		y = y,
		properties = properties,
	}
end

-- A plain rect object, NOT a template reference: real usage
-- (tests/fixtures/pressure_switch_room.lua) authors it as a bare rectangle,
-- top-left anchored like kill_zone/ladder, not a tile-object with a gid.
local function pressureSwitchObject(id, x, y, targetId)
	return {
		id = id,
		name = 'pressure_switch',
		type = 'pressure_switch',
		x = x,
		y = y,
		width = TILE,
		height = TILE,
		properties = {
			{name = 'target', type = 'object', value = targetId},
			{name = 'latching', type = 'bool', value = false},
		},
	}
end

local function pushBoxObject(id, x, y)
	return {id = id, template = '../../editor/push_box.tj', name = 'push_box', type = 'push_box', x = x, y = y}
end

local function killZoneObject(id, hazard)
	return {
		id = id,
		name = hazard.deathType .. '_kill',
		type = 'kill_zone',
		x = hazard.x,
		y = hazard.y,
		width = hazard.width,
		height = hazard.height,
		properties = {{name = 'deathType', value = hazard.deathType}},
	}
end

local function keyObject(id, x, y, color)
	return {
		id = id,
		template = '../../editor/key.tj',
		name = 'key',
		type = 'key',
		x = x,
		y = y,
		properties = {{name = 'color', value = color}},
	}
end

local function cageObject(id, x, y, color)
	return {
		id = id,
		template = '../../editor/cage.tj',
		name = 'cage',
		type = 'cage',
		x = x,
		y = y,
		properties = {{name = 'color', value = color}},
	}
end

-- Builds the kill-zone objects and a matching visual water tile layer from
-- Decorate's hazard rects. Visual tiles only fill the rows strictly between
-- the two platforms a hazard's ladder connects (never the platforms' own
-- rows), so they never overlap solid ground -- the kill volume itself still
-- covers the full gap (Decorate.hazardsForLayout), one tile-row taller than
-- what's drawn, which is an acceptable "bland" mismatch (PRD: art polish is
-- explicitly out of scope) rather than risking a solid-tile/water overlap.
local function buildHazards(hazards, startId, width, height)
	local killObjects = {}
	local waterRows = {}
	for y = 1, height do
		waterRows[y] = {}
		for x = 1, width do
			waterRows[y][x] = 0
		end
	end

	local nextId = startId
	for _, hazard in ipairs(hazards) do
		table.insert(killObjects, {
			id = nextId,
			name = hazard.deathType .. '_kill',
			type = 'kill_zone',
			x = hazard.x,
			y = hazard.y,
			width = hazard.width,
			height = hazard.height,
			properties = {{name = 'deathType', value = hazard.deathType}},
		})
		nextId = nextId + 1

		local firstCol = math.floor(hazard.x / TILE) + 1
		local lastCol = math.floor((hazard.x + hazard.width) / TILE)
		-- Skip the upper zone's own row (hazard.ladder.yTop): rows below
		-- that, for hazard.height/TILE rows, are the strictly-empty band
		-- decorate.lua actually carved out (already clearance-shrunk).
		local firstRow = hazard.ladder.yTop + 1
		local lastRow = hazard.ladder.yTop + (hazard.height / TILE)
		for row = firstRow, lastRow do
			for col = firstCol, lastCol do
				waterRows[row][col] = WATER_TILE_GID
			end
		end
	end

	return killObjects, waterRows, nextId
end

-- Difficulty scales how many optional rule flourishes get applied, not
-- chain depth -- flourishes don't chain (DECISIONS.md Q14).
local function flourishCountForDifficulty(difficulty)
	difficulty = difficulty or 1
	if difficulty >= 5 then
		return 2
	elseif difficulty >= 3 then
		return 1
	end
	return 0
end

-- A deterministic pixel position for an object standing on `zone`, offset
-- by `slot` (0, 1, 2, ...) so multiple objects on the same zone don't stack
-- on the same tile.
local function positionOnZone(zone, slot)
	local width = zone.x2 - zone.x1 + 1
	local column = zone.x1 + (slot % width)
	return (column - 1) * TILE, surfaceY(zone.y)
end

--- Builds the walking-skeleton level: flat ground across the bottom, one
-- spawn object, an exit door with actor_count 0 (open immediately -- there
-- are no objectives yet, see issue 03).
function Main.buildWalkingSkeletonMap(seed)
	local rows = {}
	for y = 1, MAP_HEIGHT do
		local row = {}
		for x = 1, MAP_WIDTH do
			row[x] = (y == GROUND_ROW) and 1 or 0
		end
		rows[y] = row
	end

	local groundSurfaceY = surfaceY(GROUND_ROW)

	return {
		width = MAP_WIDTH,
		height = MAP_HEIGHT,
		tilewidth = TILE,
		tileheight = TILE,
		nextobjectid = 3,
		properties = {
			{name = 'name', value = 'Generated ' .. tostring(seed)},
			{name = 'description', value = 'Procedurally generated level (walking skeleton)'},
			{name = 'players', type = 'int', value = 1},
		},
		tilesets = TILESETS,
		layers = {
			{
				id = 1,
				type = 'tilelayer',
				name = 'ground',
				width = MAP_WIDTH,
				height = MAP_HEIGHT,
				properties = {{name = 'collision', type = 'bool', value = true}},
				data = rows,
			},
			{
				id = 2,
				type = 'objectgroup',
				name = 'game',
				objects = {
					spawnObject(1, 2 * TILE, groundSurfaceY),
					exitObject(2, (MAP_WIDTH - 3) * TILE, groundSurfaceY, 0),
				},
			},
		},
	}
end

-- Shared terrain build: the layout, its tile grid, and its ladder objects.
-- Used by both buildTerrainMap (issue 02) and buildObjectiveMap (issue 03)
-- so the two don't duplicate tile/ladder assembly.
local function buildTerrain(seed, opts)
	local layout = Layout.generate(Rng.new(seed), {size = opts.size})

	local rows = {}
	for y = 1, layout.height do
		rows[y] = {}
		for x = 1, layout.width do
			rows[y][x] = 0
		end
	end
	for _, zone in ipairs(layout.zones) do
		for x = zone.x1, zone.x2 do
			rows[zone.y][x] = 1
		end
	end

	local ladderObjects = {}
	local rungId = 100
	for _, ladder in ipairs(layout.ladders) do
		local x = (ladder.x - 1) * TILE
		local top = surfaceY(ladder.yTop)
		-- One template rung per 32px tile, bottom-anchored (object.y = the
		-- rung's bottom edge), matching the ladder.tx convention in the
		-- hand-made maps: LadderMerger re-joins them into one logical ladder.
		for y = top + TILE, surfaceY(ladder.yBottom), TILE do
			table.insert(ladderObjects, {
				id = rungId,
				template = '../../editor/ladder.tj',
				x = x,
				y = y,
			})
			rungId = rungId + 1
		end
	end

	return layout, rows, ladderObjects, rungId
end

local function baseMapFields(seed, layout, description, background)
	local properties = {
		{name = 'name', value = 'Generated ' .. tostring(seed)},
		{name = 'description', value = description},
		{name = 'players', type = 'int', value = 1},
	}
	if background then
		table.insert(properties, {name = 'background', value = background})
	end
	return {
		width = layout.width,
		height = layout.height,
		tilewidth = TILE,
		tileheight = TILE,
		properties = properties,
		tilesets = TILESETS,
	}
end

local function coinObject(id, x, y)
	return {id = id, template = '../../editor/coin.tj', name = 'coin', type = 'coin', x = x, y = y}
end

local function enemyObject(id, x, y, enemyType)
	return {id = id, name = enemyType, type = enemyType, x = x, y = y, width = TILE, height = TILE}
end

--- Builds a level with real terrain: a ground row plus a chain of platforms
-- connected by ladders (tools.level_generator.layout), every zone
-- guaranteed reachable from spawn by construction. Spawn sits on the ground
-- zone, the exit on the topmost zone (actor_count 0 -- objectives arrive in
-- issue 03).
function Main.buildTerrainMap(seed, opts)
	opts = opts or {}
	local layout, rows, ladderObjects, nextRungId = buildTerrain(seed, opts)
	local groundZone = layout.zones[1]
	local topZone = layout.zones[#layout.zones]

	local map = baseMapFields(seed, layout, 'Procedurally generated level')
	map.nextobjectid = nextRungId
	map.layers = {
		{
			id = 1,
			type = 'tilelayer',
			name = 'ground',
			width = layout.width,
			height = layout.height,
			properties = {{name = 'collision', type = 'bool', value = true}},
			data = rows,
		},
		{
			id = 2,
			type = 'objectgroup',
			name = 'game',
			objects = {
				spawnObject(1, (groundZone.x1 + 1) * TILE, surfaceY(groundZone.y)),
				exitObject(2, (topZone.x1 - 1) * TILE, surfaceY(topZone.y), 0),
			},
		},
		{
			id = 3,
			type = 'objectgroup',
			name = 'ladder',
			objects = ladderObjects,
		},
	}
	return map
end

-- Box-fills-hole (issue 07) reserves one objective (the last one not already
-- claimed by the vault) to sit on the far side of the gap.
local function selectReservedObjective(plan, vaultObjective)
	local pushBridgeObjective = nil
	for i = #plan, 1, -1 do
		if plan[i] ~= vaultObjective then
			pushBridgeObjective = plan[i]
			break
		end
	end
	return pushBridgeObjective
end

-- One matched key+cage pair per plan objective that isn't reserved for the
-- vault or the box-bridge, each placed on its assigned zone.
local function placeStandardObjectives(layout, plan, rng, objects, vaultObjective, pushBridgeObjective, nextId)
	for _, objective in ipairs(plan) do
		if objective ~= vaultObjective and objective ~= pushBridgeObjective then
			local keyZone = layout.zones[objective.keyZoneIndex]
			local cageZone = layout.zones[objective.cageZoneIndex]
			local keySlot = rng:nextInt(0, 1000)
			local cageSlot = rng:nextInt(0, 1000)

			local keyX, keyY = positionOnZone(keyZone, keySlot)
			local cageX, cageY = positionOnZone(cageZone, cageSlot)

			table.insert(objects, keyObject(nextId, keyX, keyY, objective.color))
			nextId = nextId + 1
			table.insert(objects, cageObject(nextId, cageX, cageY, objective.color))
			nextId = nextId + 1
		end
	end
	return nextId
end

-- Optional rule flourishes (DECISIONS.md Q14): never gate anything, so
-- they're layered on after the required objects above. Objects with a
-- polyline go to a waypoints layer (matching hand-made map convention);
-- everything else joins the game objectgroup.
local function applyFlourishes(rng, layout, objects, nextId, difficulty, walkthroughSteps)
	local waypointObjects = {}
	local availableRules = RuleSet.discover()
	local flourishCount = flourishCountForDifficulty(difficulty)
	for i = 1, flourishCount do
		local rule = availableRules[((i - 1) % #availableRules) + 1]
		if rule and rule.canApply(layout) then
			local result = rule.apply(rng, layout, nextId)
			for _, object in ipairs(result.objects) do
				if object.polyline then
					table.insert(waypointObjects, object)
				else
					table.insert(objects, object)
				end
			end
			nextId = nextId + result.idsUsed
			table.insert(walkthroughSteps, result.walkthroughStep)
		end
	end
	return waypointObjects, nextId
end

-- --coop required (issue 06): a walled-off vault beyond the layout's own
-- width, entered only through a teleport a distant momentary pressure
-- plate must hold enabled -- see coop.lua's header for why this is
-- unsolvable solo by construction, not by a post-hoc solver.
local function extendForVault(layout, rows, waterRows, objects, walkthroughSteps, rng, nextId, mapWidth, vaultObjective, groundZone, topZone)
	if not vaultObjective then
		return mapWidth, nextId
	end

	local vault = Coop.planVault(layout)
	mapWidth = vault.newWidth

	for y = 1, layout.height do
		for x = layout.width + 1, mapWidth do
			rows[y][x] = 0
		end
		if waterRows then
			for x = layout.width + 1, mapWidth do
				waterRows[y][x] = 0
			end
		end
	end
	for _, cell in ipairs(vault.wallCells) do
		rows[cell.row][cell.col] = 1
	end

	local teleportBId = nextId
	local teleportAId = nextId + 1
	nextId = nextId + 3 -- teleportAId's own id slot is skipped, preserving the established numbering

	table.insert(objects, teleportObject(teleportBId, vault.interior.teleportX, vault.interior.y, teleportAId, nil))
	table.insert(objects, keyObject(nextId, vault.interior.keyX, vault.interior.y, vaultObjective.color))
	nextId = nextId + 1
	table.insert(objects, cageObject(nextId, vault.interior.cageX, vault.interior.y, vaultObjective.color))
	nextId = nextId + 1

	local plateZone = groundZone
	local plateX, plateY = positionOnZone(plateZone, rng:nextInt(0, 1000))
	table.insert(objects, teleportObject(teleportAId, (topZone.x1) * TILE, surfaceY(topZone.y), teleportBId, false))
	table.insert(objects, pressureSwitchObject(nextId, plateX, plateY, teleportAId))
	nextId = nextId + 1

	table.insert(walkthroughSteps, string.format(
		'Coop required: P1 must stand on the pressure plate (zone %d, ground) to keep the vault teleporter enabled '
			.. 'while P2 uses it (top zone) to reach the %s key and cage sealed inside the vault -- the plate '
			.. 'releases the instant P1 steps off, so one player cannot do both.',
		1, vaultObjective.color
	))

	vaultObjective.relocated = true

	return mapWidth, nextId
end

-- Box-fills-hole (issue 07): additive, like the vault, so it never
-- touches the ground zone's own tiles -- see pushables.lua's header.
-- Both extensions occupy different rows (vault near the top, this at
-- the ground row), so their column ranges can freely overlap; only the
-- overall map width needs to cover whichever reaches furthest.
local function extendForBoxBridge(layout, rows, waterRows, objects, killObjects, walkthroughSteps, nextId, mapWidth, pushBridgeObjective)
	if not pushBridgeObjective then
		return mapWidth, nextId
	end

	local bridge = Pushables.planBoxBridge(layout)
	local previousWidth = mapWidth
	mapWidth = math.max(mapWidth, bridge.newWidth)

	for y = 1, layout.height do
		for x = previousWidth + 1, mapWidth do
			rows[y][x] = 0
		end
		if waterRows then
			for x = previousWidth + 1, mapWidth do
				waterRows[y][x] = 0
			end
		end
	end
	for col = bridge.farColumns.first, bridge.farColumns.last do
		rows[bridge.groundRow][col] = 1
	end

	table.insert(objects, pushBoxObject(nextId, bridge.boxSpawnX, bridge.boxSpawnY))
	nextId = nextId + 1
	table.insert(killObjects, killZoneObject(nextId, bridge.killZone))
	nextId = nextId + 1
	table.insert(objects, keyObject(nextId, bridge.farObjectiveX, bridge.farObjectiveY, pushBridgeObjective.color))
	nextId = nextId + 1
	table.insert(objects, cageObject(nextId, bridge.farObjectiveX + TILE, bridge.farObjectiveY, pushBridgeObjective.color))
	nextId = nextId + 1

	table.insert(walkthroughSteps, string.format(
		'Push the box (right edge of the ground zone) one tile right into the gap to bridge it, then cross to '
			.. 'reach the %s key and cage on the far side. Falling into the gap before bridging it is a recoverable death, not a dead end.',
		pushBridgeObjective.color
	))

	pushBridgeObjective.relocated = true

	return mapWidth, nextId
end

-- Dressing (issue 08): a real background (DECISIONS.md Q16 -- no
-- gradient/cloud_spawner, they don't exist in src/), one coin per zone,
-- and difficulty-scaled enemies (never on a ladder column).
local function addDressing(rng, layout, difficulty, objects, nextId)
	local background = Decorate.pickBackground(rng)
	for _, coin in ipairs(Decorate.coinsForLayout(rng, layout)) do
		table.insert(objects, coinObject(nextId, coin.x, coin.y))
		nextId = nextId + 1
	end
	for _, enemy in ipairs(Decorate.enemiesForLayout(rng, layout, difficulty)) do
		table.insert(objects, enemyObject(nextId, enemy.x, enemy.y, enemy.type))
		nextId = nextId + 1
	end
	return background, nextId
end

local function assembleObjectiveMap(seed, layout, mapWidth, rows, ladderObjects, objects, waypointObjects, killObjects, waterRows, nextId, nextRungId, background)
	local map = baseMapFields(seed, layout, 'Procedurally generated level', background)
	map.width = mapWidth
	map.nextobjectid = math.max(nextId, nextRungId)
	map.layers = {
		{
			id = 1,
			type = 'tilelayer',
			name = 'ground',
			width = mapWidth,
			height = layout.height,
			properties = {{name = 'collision', type = 'bool', value = true}},
			data = rows,
		},
		{
			id = 2,
			type = 'objectgroup',
			name = 'game',
			objects = objects,
		},
		{
			id = 3,
			type = 'objectgroup',
			name = 'ladder',
			objects = ladderObjects,
		},
	}
	if #waypointObjects > 0 then
		table.insert(map.layers, {
			id = 4,
			type = 'objectgroup',
			name = 'waypoints',
			objects = waypointObjects,
		})
	end
	if #killObjects > 0 then
		table.insert(map.layers, {
			id = 5,
			type = 'tilelayer',
			name = 'water',
			width = mapWidth,
			height = layout.height,
			data = waterRows,
		})
		table.insert(map.layers, {
			id = 6,
			type = 'objectgroup',
			name = 'kill',
			objects = killObjects,
		})
	end
	return map
end

--- Builds the full objective spine on top of the terrain: one spawn, one
-- exit (opens automatically once every cage is used -- DECISIONS.md Q13,
-- there's no bird/actor_count involvement), and a matched key+cage pair per
-- plan objective (tools.level_generator.plan), each placed on its assigned
-- zone.
function Main.buildObjectiveMap(seed, opts)
	opts = opts or {}
	local rng = Rng.new(seed)
	local layout, rows, ladderObjects, nextRungId = buildTerrain(seed, opts)
	local plan = Plan.build(rng, #layout.zones)

	local groundZone = layout.zones[1]
	local topZone = layout.zones[#layout.zones]

	local objects = {
		spawnObject(1, (groundZone.x1 + 1) * TILE, surfaceY(groundZone.y)),
		exitObject(2, (topZone.x1 - 1) * TILE, surfaceY(topZone.y), 0),
	}
	local walkthroughSteps = {}

	-- --coop required (issue 06) reserves the last plan objective for the
	-- vault instead of placing it on a normal zone -- see the vault
	-- construction below.
	local coopRequired = opts.coop == 'required'
	local vaultObjective = coopRequired and plan[#plan] or nil
	local pushBridgeObjective = selectReservedObjective(plan, vaultObjective)

	local nextId = placeStandardObjectives(layout, plan, rng, objects, vaultObjective, pushBridgeObjective, 3)

	local waypointObjects
	waypointObjects, nextId = applyFlourishes(rng, layout, objects, nextId, opts.difficulty, walkthroughSteps)

	-- Hazards (issue 05): one kill-zone band per hazarded ladder gap, scaled
	-- by --difficulty, plus a matching visual water tile layer. Never on the
	-- solution route -- see decorate.lua's header comment.
	local hazards = Decorate.hazardsForLayout(rng, layout, opts.difficulty)
	local killObjects, waterRows
	killObjects, waterRows, nextId = buildHazards(hazards, nextId, layout.width, layout.height)

	local mapWidth = layout.width
	mapWidth, nextId = extendForVault(layout, rows, waterRows, objects, walkthroughSteps, rng, nextId, mapWidth, vaultObjective, groundZone, topZone)
	mapWidth, nextId = extendForBoxBridge(layout, rows, waterRows, objects, killObjects, walkthroughSteps, nextId, mapWidth, pushBridgeObjective)

	local background
	background, nextId = addDressing(rng, layout, opts.difficulty, objects, nextId)

	local map = assembleObjectiveMap(seed, layout, mapWidth, rows, ladderObjects, objects, waypointObjects, killObjects, waterRows, nextId, nextRungId, background)

	return map, plan, walkthroughSteps
end

--- Pure generation core: given a base seed and item count, returns one
-- {seed, filename, xml} entry per level. No filesystem access, so it's
-- directly unit-testable. Item i's seed is derived from the base seed
-- (Rng.deriveSeed) so each item in a batch is independently reproducible.
function Main.generate(opts)
	opts = opts or {}
	local baseSeed = opts.seed
	local count = opts.count or 1

	local results = {}
	for i = 0, count - 1 do
		local itemSeed
		if count == 1 then
			itemSeed = baseSeed
		else
			itemSeed = Rng.deriveSeed(baseSeed, i)
		end

		local map, plan, flourishSteps = Main.buildObjectiveMap(itemSeed, {size = opts.size, difficulty = opts.difficulty, coop = opts.coop})
		local walkthroughPlan = {}
		for _, objective in ipairs(plan) do
			if not objective.relocated then
				table.insert(walkthroughPlan, objective)
			end
		end
		local tmj = TmjWriter.write(map)
		local solutionText = Walkthrough.build(walkthroughPlan, flourishSteps)
		table.insert(results, {
			seed = itemSeed,
			filename = string.format('%d.tmj', itemSeed),
			xml = tmj,
			solutionFilename = string.format('%d-solution.md', itemSeed),
			solutionText = solutionText,
		})
	end

	return results
end

local function parseArgs(argv)
	local opts = {count = 1}
	local i = 1
	while i <= #argv do
		local a = argv[i]
		if a == '--seed' then
			i = i + 1
			opts.seed = tonumber(argv[i])
			if not opts.seed then
				error('--seed requires a numeric value')
			end
		elseif a == '--count' then
			i = i + 1
			opts.count = tonumber(argv[i])
			if not opts.count or opts.count < 1 then
				error('--count requires a positive integer')
			end
		elseif a == '--size' then
			i = i + 1
			opts.size = argv[i]
			if opts.size ~= 'small' and opts.size ~= 'medium' and opts.size ~= 'large' then
				error('--size must be one of small|medium|large')
			end
		elseif a == '--difficulty' then
			i = i + 1
			opts.difficulty = tonumber(argv[i])
			if not opts.difficulty or opts.difficulty < 1 or opts.difficulty > 5 then
				error('--difficulty must be an integer from 1 to 5')
			end
		elseif a == '--coop' then
			i = i + 1
			opts.coop = argv[i]
			if opts.coop ~= 'required' and opts.coop ~= 'optional' then
				error('--coop must be one of required|optional')
			end
		else
			error('Unrecognised argument: ' .. tostring(a))
		end
		i = i + 1
	end
	return opts
end

local function writeFile(path, contents)
	local file, err = io.open(path, 'w')
	if not file then
		error('Failed to write "' .. path .. '": ' .. tostring(err))
	end
	file:write(contents)
	file:close()
end

--- CLI entrypoint: parses argv, generates, writes .tmj files to
-- res/map/generated/, and prints each seed (so unseeded/random runs can be
-- reproduced later).
function Main.run(argv, outputDir)
	outputDir = outputDir or 'res/map/generated'

	local ok, opts = pcall(parseArgs, argv)
	if not ok then
		io.stderr:write('Error: ' .. tostring(opts) .. '\n')
		os.exit(1)
	end

	if not opts.seed then
		opts.seed = os.time()
	end

	local results = Main.generate(opts)
	for _, result in ipairs(results) do
		local path = outputDir .. '/' .. result.filename
		writeFile(path, result.xml)
		writeFile(outputDir .. '/' .. result.solutionFilename, result.solutionText)
		print(string.format('seed=%d -> %s', result.seed, path))
	end
end

if arg and arg[0] and arg[0]:match('main%.lua$') then
	-- arg[1..] here excludes arg[0] itself (standard Lua CLI convention).
	Main.run(arg)
end

return Main
