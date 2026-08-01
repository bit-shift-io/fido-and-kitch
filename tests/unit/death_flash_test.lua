-- Shared death/spawn flash-and-fade sequence (see player_death_test.lua /
-- npc_death_test.lua for the Player/NPC call sites that rely on this).
Class = Class or require('lib.hump.class')
Tween = Tween or require('lib.tween.tween')
local DeathFlash = require('src.components.death_flash')

local function makeEntity()
	local entity = {alpha = 1, visible = true, components = {}}
	function entity:addComponent(component)
		table.insert(self.components, component)
		return component
	end
	return entity
end

test('death sequence starts at full alpha and fades toward zero', function()
	local entity = makeEntity()

	DeathFlash.startDeath(entity)

	assertEqual(1, entity.alpha)
	entity.fadeTween:update(DeathFlash.FADE_DURATION)
	assertEqual(0, entity.alpha)
end)

test('death sequence blocks on a flash that gates its onComplete callback', function()
	local entity = makeEntity()
	local completed = false

	DeathFlash.startDeath(entity, function() completed = true end)

	for _ = 1, DeathFlash.FLASH_BLINKS do
		entity.flash:update(DeathFlash.FLASH_INTERVAL)
	end

	assertTrue(completed, 'expected the death flash to gate its onComplete callback')
end)

test('spawn sequence starts at zero alpha and fades toward full', function()
	local entity = makeEntity()

	DeathFlash.startSpawn(entity)

	assertEqual(0, entity.alpha)
	entity.fadeTween:update(DeathFlash.FADE_DURATION)
	assertEqual(1, entity.alpha)
end)

test('spawn sequence is non-blocking -- no onComplete gate', function()
	local entity = makeEntity()

	DeathFlash.startSpawn(entity)

	for _ = 1, DeathFlash.FLASH_BLINKS do
		entity.flash:update(DeathFlash.FLASH_INTERVAL)
	end

	assertTrue(true, 'expected no error from a spawn flash with no onComplete callback')
end)

test('death and spawn sequences use the same shared flash timing constants', function()
	assertEqual(0.15, DeathFlash.FLASH_INTERVAL)
	assertEqual(8, DeathFlash.FLASH_BLINKS)
	assertNear(1.2, DeathFlash.FADE_DURATION, 0.0001)
end)
