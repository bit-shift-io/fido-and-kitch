-- Spider-specific death behaviour: force-releasing a wrapped player the
-- instant the Spider dies, rather than waiting for the web's own expiry
-- timer or the Spider's respawn. See tests/unit/npc_death_test.lua for the
-- shared die/respawn coverage (Robot stands in for the base NPC behaviour
-- this reuses unmodified), and tests/integration/spider_wrap_release_test.lua
-- for the real-player, real-web end-to-end version of this.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local Spider = require('src.entities.spider')

local function makeSpider(x, y)
	HeadlessBootstrap.resetWorld()
	return Spider({x = x, y = y, width = 24, height = 24, properties = {}})
end

test('a Spider that dies with no wrapped target behaves like a Robot -- no error, no special-casing', function()
	local spider = makeSpider(100, 100)

	spider:die('water')

	assertTrue(spider:isDead())
end)

test('a Spider that dies while it has a player wrapped releases that player immediately', function()
	local spider = makeSpider(100, 100)
	local fakePlayer = {
		wrapped = true,
		releaseWrap = function(self) self.wrapped = false end,
	}
	spider.wrappedTarget = fakePlayer

	spider:die('water')

	assertFalse(fakePlayer.wrapped, 'expected the wrapped player to be force-released')
	assertEqual(nil, spider.wrappedTarget, 'expected the Spider to forget its wrapped target once released')
end)

test('a Spider that dies with an already-unwrapped target does not error or double-release', function()
	local spider = makeSpider(100, 100)
	local calls = 0
	local fakePlayer = {
		wrapped = false,
		releaseWrap = function(self) calls = calls + 1 end,
	}
	spider.wrappedTarget = fakePlayer

	spider:die('water')

	assertEqual(0, calls)
end)
