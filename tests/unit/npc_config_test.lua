-- Unit tests for src/npc/npc_config.lua: the defaults merge used by every
-- NPC. Verifies mergeWithDefaults layers config defaults under per-NPC props
-- and getDefaults returns a defensive copy.
local NPCConfig = require('src.npc.npc_config')

test('getDefaults returns a fresh copy, not the shared table', function()
	local a = NPCConfig.getDefaults()
	a.maxSpeed = 999
	local b = NPCConfig.getDefaults()
	assertEqual(80, b.maxSpeed)
end)

test('mergeWithDefaults fills unset fields from config defaults', function()
	local merged = NPCConfig.mergeWithDefaults({})
	assertEqual(80, merged.maxSpeed)
	assertEqual('wander', merged.behavior)
	assertEqual(1, merged.health)
end)

test('mergeWithDefaults lets props override config defaults', function()
	local merged = NPCConfig.mergeWithDefaults({ maxSpeed = 120, behavior = 'chase' })
	assertEqual(120, merged.maxSpeed)
	assertEqual('chase', merged.behavior)
end)

test('live defaults required by NPC logic are present', function()
	local merged = NPCConfig.mergeWithDefaults({})
	assertEqual(nil, merged.canPush, 'canPush was removed as unused')
	assertEqual(nil, merged.pushForce, 'pushForce was removed as unused')
	assertEqual(0, merged.despawnDistance)
	assertEqual(false, merged.ridePlatforms)
end)
