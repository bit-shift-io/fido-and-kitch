local Web = require('src.npc.web')

test('a fresh web is not expired', function()
	local web = Web{duration = 20}

	assertFalse(web:isExpired())
end)

test('a web expires once its duration elapses', function()
	local web = Web{duration = 20}

	web:update(19)
	assertFalse(web:isExpired())

	web:update(2)
	assertTrue(web:isExpired())
end)

test('a web is fully opaque outside its fade window', function()
	local web = Web{duration = 20, fadeDuration = 3}

	web:update(10)

	assertEqual(1, web:alpha())
end)

test('a web fades linearly during its fade window', function()
	local web = Web{duration = 20, fadeDuration = 4}

	web:update(18)

	assertNear(0.5, web:alpha())
end)

test('a web is fully faded once expired', function()
	local web = Web{duration = 20, fadeDuration = 4}

	web:update(20)

	assertEqual(0, web:alpha())
end)
