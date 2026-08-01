-- End-to-end: a Spider that has wrapped a player releases them immediately
-- the instant it dies, rather than waiting for the web's own expiry timer --
-- driven through the real Game/Map/World/Player stack. See
-- tests/unit/spider_wrap_release_test.lua for the pure release-hook
-- coverage this doesn't repeat, and tests/integration/npc_kill_zone_respawn_test.lua
-- for the shared die/respawn behaviour (flash, 30s delay, origin restore)
-- this reuses unmodified.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/spider_wrap_room.lua'

-- GameHarness always spawns two players at every "spawn" object (local
-- co-op), so whichever one the Spider happens to query first in the world
-- overlap gets wrapped -- find it rather than assuming players[1].
local function findWrappedPlayer(game)
	for _, player in ipairs(game.fsm.currentState.players) do
		if player.wrapped then
			return player
		end
	end
	return nil
end

local function findSpider()
	return Queries.findEntityByType(map, 'spider')
end

test('a Spider that dies while it has a player wrapped releases them immediately, well short of the web expiry', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 30) -- let both settle onto the floor and the Spider wrap the overlapping player

	local player = findWrappedPlayer(game)
	local spider = findSpider()
	assertTrue(player ~= nil, 'fixture check: expected the Spider to have wrapped a player')
	assertEqual(player, spider.wrappedTarget, 'fixture check: expected the Spider to be tracking the player it wrapped')

	spider:die('lava') -- simulate kill-zone contact
	FrameStepper.step(game, 1)

	assertFalse(player.wrapped, 'expected the wrapped player to be released the instant the Spider died')
	assertEqual(player.fsm.states.WalkIdleState, player.fsm.currentState)
end)

test('a Spider that dies with no one wrapped behaves identically to a Robot -- dies and stays dead, no error', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 5) -- before the Spider has had a chance to wrap anyone

	local spider = findSpider()
	spider:die('lava')
	FrameStepper.step(game, 1)

	assertTrue(spider:isDead())
end)
