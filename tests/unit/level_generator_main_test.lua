local Main = require("tools.level_generator.main")
local MovementModel = require("tools.level_generator.movement_model")

test("generate with an explicit seed reproduces byte-identical output", function()
	local a = Main.generate({ seed = 42, count = 1 })
	local b = Main.generate({ seed = 42, count = 1 })

	assertEqual(a[1].tmj, b[1].tmj)
	assertEqual(42, a[1].seed)
end)

test("different seeds produce different filenames", function()
	local a = Main.generate({ seed = 1, count = 1 })
	local b = Main.generate({ seed = 2, count = 1 })

	assertFalse(a[1].filename == b[1].filename)
end)

test("--count N produces N independently reproducible items", function()
	local batchA = Main.generate({ seed = 100, count = 3 })
	local batchB = Main.generate({ seed = 100, count = 3 })

	assertEqual(3, #batchA)
	for i = 1, 3 do
		assertEqual(batchA[i].seed, batchB[i].seed)
		assertEqual(batchA[i].tmj, batchB[i].tmj)
	end

	assertFalse(batchA[1].seed == batchA[2].seed)
	assertFalse(batchA[2].seed == batchA[3].seed)
end)

test("walking skeleton map has one spawn and an exit with actor_count 0", function()
	local map = Main.buildWalkingSkeletonMap(42)
	local gameLayer = map.layers[2]

	assertEqual(2, #gameLayer.objects)
	assertEqual("spawn", gameLayer.objects[1].name)
	assertEqual("exit_door", gameLayer.objects[2].name)
	assertEqual(0, gameLayer.objects[2].properties[1].value)
end)

test("generate produces terrain sized by --size, with every zone reachable", function()
	local map = Main.buildTerrainMap(42, { size = "large" })

	assertEqual(56, map.width)
	assertTrue(map.height >= 30)
end)

test("terrain map still has exactly one spawn and one exit with actor_count 0", function()
	local map = Main.buildTerrainMap(42, { size = "medium" })
	local gameLayer = map.layers[#map.layers - 1]

	local spawnCount, exitCount = 0, 0
	for _, object in ipairs(gameLayer.objects) do
		if object.name == "spawn" then
			spawnCount = spawnCount + 1
		end
		if object.name == "exit_door" then
			exitCount = exitCount + 1
			assertEqual(0, object.properties[1].value)
		end
	end
	assertEqual(1, spawnCount)
	assertEqual(1, exitCount)
end)

test("terrain map emits one template rung per ladder tile, bottom-anchored", function()
	function surfaceY(row)
		return (row - 1) * 32
	end
	local Layout = require("tools.level_generator.layout")
	local Rng = require("tools.level_generator.rng")
	local layout = Layout.generate(Rng.new(42), { size = "medium" })

	local map = Main.buildTerrainMap(42, { size = "medium" })
	local ladderLayer = map.layers[#map.layers]

	assertEqual("ladder", ladderLayer.name)
	local expectedRungs = 0
	for _, ladder in ipairs(layout.ladders) do
		expectedRungs = expectedRungs + (surfaceY(ladder.yBottom) - surfaceY(ladder.yTop)) / 32
	end
	assertEqual(expectedRungs, #ladderLayer.objects)
	for _, object in ipairs(ladderLayer.objects) do
		assertEqual("../../entities/ladder.tj", object.template)
		assertEqual(nil, object.type)
		assertEqual(nil, object.width)
		assertEqual(nil, object.height)
		assertEqual(0, object.y % 32, "rung bottom edge must sit on a 32px grid boundary")
	end
end)

test("generate() (the CLI pipeline) uses terrain, not just the walking skeleton", function()
	local json = require("lib.dkjson")
	local result = Main.generate({ seed = 42, count = 1, size = "medium" })[1]
	local decoded = json.decode(result.tmj)
	assertTrue(decoded ~= nil, "generated output must be valid tmj JSON")
	local ladderLayerFound = false
	for _, layer in ipairs(decoded.layers) do
		if layer.name == "ladder" and layer.type == "objectgroup" then
			ladderLayerFound = true
		end
	end
	assertTrue(ladderLayerFound, "expected a ladder layer in the generated output")
end)

test("objective map has a matched key and cage per objective, and still one spawn/exit", function()
	local map = Main.buildObjectiveMap(42, { size = "medium" })
	local gameLayer = map.layers[2]

	local counts = { spawn = 0, exit_door = 0, key = 0, cage = 0 }
	local keyColors, cageColors = {}, {}
	for _, object in ipairs(gameLayer.objects) do
		counts[object.name] = (counts[object.name] or 0) + 1
		if object.type == "key" then
			for _, prop in ipairs(object.properties) do
				if prop.name == "color" then
					keyColors[prop.value] = true
				end
			end
		end
		if object.type == "cage" then
			for _, prop in ipairs(object.properties) do
				if prop.name == "color" then
					cageColors[prop.value] = true
				end
			end
		end
	end

	assertEqual(1, counts.spawn)
	assertEqual(1, counts.exit_door)
	assertTrue(counts.key >= 1)
	assertEqual(counts.key, counts.cage)

	for color in pairs(keyColors) do
		assertTrue(cageColors[color], "expected a matching cage for key color " .. color)
	end
end)

test("difficulty monotonically increases the number of flourish rules applied", function()
	local counts = {}
	for _, difficulty in ipairs({ 1, 2, 3, 4, 5 }) do
		local map = Main.buildObjectiveMap(42, { size = "large", difficulty = difficulty })
		local waypointsLayer = nil
		for _, layer in ipairs(map.layers) do
			if layer.name == "waypoints" then
				waypointsLayer = layer
			end
		end
		local switchCount = 0
		for _, object in ipairs(map.layers[2].objects) do
			if object.type == "switch" then
				switchCount = switchCount + 1
			end
		end
		counts[difficulty] = switchCount
	end

	assertTrue(counts[1] <= counts[3], "expected difficulty 3 to have at least as many flourishes as difficulty 1")
	assertTrue(counts[3] <= counts[5], "expected difficulty 5 to have at least as many flourishes as difficulty 3")
	assertTrue(counts[5] > counts[1], "expected difficulty 5 to have strictly more flourishes than difficulty 1")
end)

test("flourishes never remove the required spawn/exit/key/cage objects", function()
	local map = Main.buildObjectiveMap(42, { size = "large", difficulty = 5 })
	local names = {}
	for _, object in ipairs(map.layers[2].objects) do
		names[object.name] = (names[object.name] or 0) + 1
	end
	assertEqual(1, names.spawn)
	assertEqual(1, names.exit_door)
	assertTrue(names.key >= 1)
end)

test("difficulty 1 has no water (ladder-gap) hazards; difficulty 5 has at least one", function()
	-- The box-bridge's own guard-rail kill zone (deathType 'pit', issue 07)
	-- is unconditional, independent of --difficulty -- only the ladder-gap
	-- hazards from issue 05 (deathType 'water') scale with it.
	local function waterKillCount(map)
		local count = 0
		for _, layer in ipairs(map.layers) do
			for _, object in ipairs(layer.objects or {}) do
				if object.type == "kill_zone" then
					for _, prop in ipairs(object.properties) do
						if prop.name == "deathType" and prop.value == "water" then
							count = count + 1
						end
					end
				end
			end
		end
		return count
	end

	local calm = Main.buildObjectiveMap(3, { size = "large", difficulty = 1 })
	local deadly = Main.buildObjectiveMap(3, { size = "large", difficulty = 5 })

	assertEqual(0, waterKillCount(calm), "expected no water hazards at difficulty 1")
	assertTrue(waterKillCount(deadly) >= 1, "expected at least one water hazard at difficulty 5")
end)

test("--coop optional (default) never places a pressure switch or vault teleport", function()
	local map = Main.buildObjectiveMap(9, { size = "medium" })
	for _, layer in ipairs(map.layers) do
		for _, object in ipairs(layer.objects or {}) do
			assertFalse(object.type == "pressure_switch", "expected no pressure switch without --coop required")
		end
	end
end)

test("--coop required places a pressure switch, a disabled vault teleport, and a vault key+cage", function()
	local map = Main.buildObjectiveMap(9, { size = "medium", coop = "required" })
	local gameLayer = map.layers[2]

	local sawSwitch, sawDisabledTeleport, sawEnabledTeleport = false, false, false
	for _, object in ipairs(gameLayer.objects) do
		if object.type == "pressure_switch" then
			sawSwitch = true
		end
		if object.type == "teleport" then
			for _, prop in ipairs(object.properties or {}) do
				if prop.name == "enabled" and prop.value == false then
					sawDisabledTeleport = true
				end
			end
			if not object.properties or #object.properties == 1 then
				sawEnabledTeleport = true
			end
		end
	end

	assertTrue(sawSwitch, "expected a pressure switch")
	assertTrue(sawDisabledTeleport, "expected a teleport authored with enabled=false")
end)

test("--coop required still keeps every non-vault objective on a normal, reachable zone", function()
	local map, plan = Main.buildObjectiveMap(9, { size = "medium", coop = "required" })
	local gameLayer = map.layers[2]

	local keyCount, cageCount = 0, 0
	for _, object in ipairs(gameLayer.objects) do
		if object.type == "key" then
			keyCount = keyCount + 1
		end
		if object.type == "cage" then
			cageCount = cageCount + 1
		end
	end
	assertEqual(#plan, keyCount)
	assertEqual(#plan, cageCount)
end)

test("every objective map includes a push_box bridging a far-side key/cage", function()
	local map, plan = Main.buildObjectiveMap(9, { size = "medium" })
	local gameLayer = map.layers[2]

	local sawBox, farKeyCount, farCageCount = false, 0, 0
	for _, object in ipairs(gameLayer.objects) do
		if object.type == "push_box" then
			sawBox = true
		end
	end
	assertTrue(sawBox, "expected a push_box object")

	local relocatedCount = 0
	for _, objective in ipairs(plan) do
		if objective.relocated then
			relocatedCount = relocatedCount + 1
		end
	end
	assertTrue(relocatedCount >= 1, "expected at least one relocated objective (box-bridge and/or vault)")
end)

test("objective maps set a real background property and include coins", function()
	local map = Main.buildObjectiveMap(9, { size = "medium" })
	local REAL_BACKGROUNDS = { night_forest = true, mushroom_cave = true, sky = true }

	local background = nil
	for _, prop in ipairs(map.properties) do
		if prop.name == "background" then
			background = prop.value
		end
	end
	assertTrue(REAL_BACKGROUNDS[background], "expected a real background property")

	local coinCount = 0
	for _, object in ipairs(map.layers[2].objects) do
		if object.type == "coin" then
			coinCount = coinCount + 1
		end
	end
	assertTrue(coinCount >= 1, "expected at least one coin")
end)

test("difficulty 1 objective maps have no enemies; difficulty 5 has at least one", function()
	local calm = Main.buildObjectiveMap(9, { size = "large", difficulty = 1 })
	local deadly = Main.buildObjectiveMap(9, { size = "large", difficulty = 5 })

	local function enemyCount(map)
		local count = 0
		for _, object in ipairs(map.layers[2].objects) do
			if object.type == "npc_spider" or object.type == "npc_robot" then
				count = count + 1
			end
		end
		return count
	end

	assertEqual(0, enemyCount(calm))
	assertTrue(enemyCount(deadly) >= 1)
end)

test("generate() writes a solution walkthrough alongside the .tmj", function()
	local result = Main.generate({ seed = 42, count = 1, size = "medium" })[1]
	assertTrue(result.solutionFilename ~= nil)
	assertTrue(result.solutionText:find("exit opens automatically") ~= nil)
end)
