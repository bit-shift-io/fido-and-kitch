Class = Class or require('lib.hump.class')
local Switchable = require('src.components.switchable')

local function fakeEntity()
	local entity = {calls = {}}
function entity.onStateChange(enabled, switch, user)
	table.insert(entity.calls, {name = 'onStateChange', enabled = enabled, switch = switch, user = user})
end
	return entity
end

test('init defaults enabled to true when props.enabled is nil', function()
	local entity = fakeEntity()
	local switchable = Switchable{entity = entity, onStateChange = entity.onStateChange}

	assertEqual('switchable', switchable.type)
	assertEqual(entity, switchable.entity)
	assertTrue(switchable.enabled)
end)

test('init honours props.enabled == false', function()
	local entity = fakeEntity()
	local switchable = Switchable{entity = entity, onStateChange = entity.onStateChange, enabled = false}

	assertFalse(switchable.enabled)
end)

test('switch({state=on}) enables and calls onStateChange(true)', function()
	local entity = fakeEntity()
	local switchable = Switchable{entity = entity, onStateChange = entity.onStateChange, enabled = false}
	local switch = {state = 'on'}
	local user = {name = 'player1'}

	switchable:switch(switch, user)

	assertTrue(switchable.enabled)
	assertEqual(1, #entity.calls)
	assertEqual('onStateChange', entity.calls[1].name)
	assertEqual(true, entity.calls[1].enabled)
end)

test('switch({state=off}) disables and calls onStateChange(false)', function()
	local entity = fakeEntity()
	local switchable = Switchable{entity = entity, onStateChange = entity.onStateChange}
	local switch = {state = 'off'}
	local user = {name = 'player1'}

	switchable:switch(switch, user)

	assertFalse(switchable.enabled)
	assertEqual(1, #entity.calls)
	assertEqual('onStateChange', entity.calls[1].name)
	assertEqual(false, entity.calls[1].enabled)
end)

test('switch forwards switch and user args to onStateChange', function()
	local entity = fakeEntity()
	local switchable = Switchable{entity = entity, onStateChange = entity.onStateChange}
	local switch = {state = 'on'}
	local user = {name = 'player2'}

	switchable:switch(switch, user)

	assertEqual(switch, entity.calls[1].switch)
	assertEqual(user, entity.calls[1].user)
end)
