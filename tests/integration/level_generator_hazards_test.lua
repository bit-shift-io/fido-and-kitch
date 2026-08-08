-- Issue 05 (hazards): kill zones must load as real hazards that kill on
-- contact, but the solution route (walking each zone, climbing every
-- ladder) must never touch one -- careless play (falling off a platform
-- edge instead of using the ladder) should.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local Main = require('tools.level_generator.main')
local Layout = require('tools.level_generator.layout')
local Rng = require('tools.level_generator.rng')

local GENERATED_PATH = 'res/map/generated/_test_hazards.tmx'

local function writeGeneratedFixture(seed, size, difficulty)
	local result = Main.generate({seed = seed, count = 1, size = size, difficulty = difficulty})[1]
	local file = io.open(GENERATED_PATH, 'w')
	file:write(result.xml)
	file:close()
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

test('a difficulty-5 generated level has real kill zones, and the ladder column stays clear of them', function()
	local layout = Layout.generate(Rng.new(21), {size = 'large'})
	writeGeneratedFixture(21, 'large', 5)

	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 90) -- long enough to settle and reveal a spawn-into-hazard bug

		for _, player in ipairs(game.fsm.currentState.players) do
			assertFalse(Queries.playerIsDead(player), 'a player died just from spawning/settling -- a hazard likely overlaps the spawn/standing space')
		end

		-- Only the ladder-gap hazards (issue 05, deathType 'water') are
		-- checked against ladder columns below; the box-bridge's own guard
		-- rail (issue 07, deathType 'pit') isn't tied to any ladder.
		local killZones = {}
		for _, kz in ipairs(map:getEntitiesByType('kill_zone')) do
			assertTrue(kz.isKillZone, 'expected a real KillZone entity')
			if kz.deathType == 'water' then
				table.insert(killZones, kz)
			end
		end
		assertTrue(#killZones >= 1, 'expected at least one generated water kill zone')

		-- Every ladder's own column (its horizontal centre) must not overlap
		-- any kill zone -- i.e. climbing the intended route is always safe.
		for _, ladder in ipairs(layout.ladders) do
			local ladderCentreX = (ladder.x - 0.5) * 32
			local ladderTop = (ladder.yTop - 1) * 32
			local ladderBottom = (ladder.yBottom - 1) * 32
			for _, kz in ipairs(killZones) do
				local bounds = kz.rect
				local overlapsX = ladderCentreX > bounds.x and ladderCentreX < (bounds.x + bounds.width)
				local overlapsY = bounds.y < ladderBottom and (bounds.y + bounds.height) > ladderTop
				assertFalse(overlapsX and overlapsY, 'a kill zone overlaps a ladder column')
			end
		end
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)
