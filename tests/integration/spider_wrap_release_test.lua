-- End-to-end: a Spider that has wrapped a player releases them immediately
-- the instant it dies, rather than waiting for the web's own expiry timer --
-- driven through the real Game/Map/World/Player stack. See
-- tests/unit/spider_wrap_release_test.lua for the pure release-hook
-- coverage this doesn't repeat, and tests/integration/npc_kill_zone_respawn_test.lua
-- for the shared die/respawn behaviour (flash, respawn delay, origin restore)
-- this reuses unmodified.
require('tests.support.headless_bootstrap')

local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local NPCRegistry = require('src.npc.npc_registry')

local MAP = 'tests/fixtures/spider_wrap_room.lua'

-- Register NPC types once before all tests
local Spider = require('src.entities.npc_spider')
NPCRegistry.clear()
NPCRegistry.registerType('npc_spider', Spider)

-- GameHarness always spawns two players at every "spawn" object (local
-- co-op); the first player is enough to set up a wrap.
local function player1(game)
	return game.fsm.currentState.players[1]
end

local function findSpider()
	return NPCRegistry.getByType('npc_spider')[1]
end

test('a Spider that dies while it has a player wrapped releases them immediately, well short of the web expiry', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 30) -- let everything settle onto the floor

	local spider = findSpider()
	assertTrue(spider ~= nil, 'fixture check: expected the Spider to have spawned')

	-- The Spider's automatic wrap trigger isn't implemented yet (the release
	-- hook in npc_spider.lua and Player's WrappedState are; nothing in
	-- gameplay calls Player:wrap()), so set the wrapped state up through the
	-- real Player:wrap() API and track it on the Spider -- the same state a
	-- real wrap would produce -- then exercise the death-release contract
	-- through the real Game/Map/World/Player stack.
	local player = player1(game)
	player:wrap(5)
	spider.wrappedTarget = player
	assertTrue(player.wrapped, 'fixture check: expected the player to be wrapped')

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
