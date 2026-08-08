local Walkthrough = require('tools.level_generator.walkthrough')

test('emits one take-key and one use-cage line per objective, in that order', function()
	local plan = {
		{color = 'red', keyZoneIndex = 1, cageZoneIndex = 2},
		{color = 'blue', keyZoneIndex = 2, cageZoneIndex = 1},
	}

	local text = Walkthrough.build(plan)

	local redKeyPos = text:find('take the red key')
	local redCagePos = text:find('use the red cage')
	assertTrue(redKeyPos ~= nil, 'expected a take-red-key step')
	assertTrue(redCagePos ~= nil, 'expected a use-red-cage step')
	assertTrue(redKeyPos < redCagePos, 'the key step must come before its cage step')

	assertTrue(text:find('take the blue key') ~= nil)
	assertTrue(text:find('use the blue cage') ~= nil)
end)

test('ends by noting the exit opens automatically once every cage is used', function()
	local plan = {{color = 'red', keyZoneIndex = 1, cageZoneIndex = 1}}
	local text = Walkthrough.build(plan)

	assertTrue(text:find('exit opens automatically') ~= nil)
end)

test('same plan produces identical walkthrough text (determinism)', function()
	local plan = {{color = 'red', keyZoneIndex = 1, cageZoneIndex = 2}}
	assertEqual(Walkthrough.build(plan), Walkthrough.build(plan))
end)
