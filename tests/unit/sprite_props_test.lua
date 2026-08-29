require('tests.support.headless_bootstrap')

local SpriteProps = require('src.entities.sprite_props')

test('sprite props: reads art fields from merged properties', function()
	local art = SpriteProps.fromObject{ properties = {
		image = 'res/img/coins.png',
		frames = 8,
		duration = 1.0,
		loop = true,
		playing = true,
		scaleX = 0.8,
		scaleY = 0.8,
	} }

	assertEqual('res/img/coins.png', art.image)
	assertEqual(8, art.frames)
	assertEqual(1.0, art.duration)
	assertEqual(true, art.loop)
	assertEqual(true, art.playing)
	assertEqual(0.8, art.scale.x)
	assertEqual(0.8, art.scale.y)
end)

test('sprite props: absent keys stay nil so Sprite defaults apply', function()
	local art = SpriteProps.fromObject{ properties = { image = 'res/img/entity_key.png' } }

	assertEqual('res/img/entity_key.png', art.image)
	assertEqual(nil, art.frames)
	assertEqual(nil, art.duration)
	assertEqual(nil, art.loop)
	assertEqual(nil, art.playing)
	assertEqual(nil, art.scale)
end)

test('sprite props: object without properties yields an empty art table', function()
	local a = SpriteProps.fromObject{ properties = nil }
	local b = SpriteProps.fromObject(nil)

	assertEqual(nil, a.image)
	assertEqual(nil, a.scale)
	assertEqual(nil, b.image)
	assertEqual(nil, b.scale)
end)

test('sprite props: a single axis scale defaults the other to 1', function()
	local art = SpriteProps.fromObject{ properties = { scaleY = 0.5 } }

	assertEqual(1, art.scale.x)
	assertEqual(0.5, art.scale.y)
end)