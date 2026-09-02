-- Coverage for the small seam added to src/entities/teleport.lua so a level
-- can author a teleporter that starts blocked until a switch/pressure-plate
-- turns it on. Existing maps never
-- author `enabled`, so the default (true) must be unchanged -- see
-- tests/integration/switchable_teleport_test.lua's "starts enabled" case,
-- which stays green.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local Teleport = require('src.entities.teleport')

local function makeTeleport(properties)
	HeadlessBootstrap.resetWorld()
	return Teleport({
		x = 96, y = 96, width = 32, height = 32,
		properties = properties,
	})
end

test('with no enabled property authored, a teleporter starts usable (unchanged default)', function()
	local teleport = makeTeleport({})
	assertTrue(teleport.usable.enabled)
end)

test('an authored enabled=false teleporter starts blocked', function()
	local teleport = makeTeleport({enabled = false})
	assertFalse(teleport.usable.enabled)
end)

test('an authored enabled=true teleporter starts usable', function()
	local teleport = makeTeleport({enabled = true})
	assertTrue(teleport.usable.enabled)
end)
