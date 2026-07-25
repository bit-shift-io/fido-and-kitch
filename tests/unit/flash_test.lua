Class = Class or require('lib.hump.class')
local Flash = require('src.components.flash')

test('flash starts with the target property visible', function()
	local target = {}
	Flash{target = target, property = 'visible', interval = 0.1, blinks = 4}

	assertEqual(true, target.visible)
end)

test('flash toggles the target property once per interval', function()
	local target = {}
	local flash = Flash{target = target, property = 'visible', interval = 0.1, blinks = 4}

	flash:update(0.1)
	assertEqual(false, target.visible)

	flash:update(0.1)
	assertEqual(true, target.visible)
end)

test('flash calls onComplete after the requested number of blinks, leaving the target visible', function()
	local target = {}
	local completed = false
	local flash = Flash{
		target = target,
		property = 'visible',
		interval = 0.1,
		blinks = 2,
		onComplete = function() completed = true end,
	}

	flash:update(0.1)
	flash:update(0.1)

	assertEqual(true, completed)
	assertEqual(true, target.visible)
end)

test('flash is inert after completion', function()
	local target = {}
	local completions = 0
	local flash = Flash{
		target = target,
		property = 'visible',
		interval = 0.1,
		blinks = 2,
		onComplete = function() completions = completions + 1 end,
	}

	flash:update(0.1)
	flash:update(0.1)
	flash:update(0.1)
	flash:update(0.1)

	assertEqual(1, completions)
end)
