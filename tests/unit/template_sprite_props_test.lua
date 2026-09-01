-- Template-driven sprite data. Every templated entity that renders a Sprite
-- advertises its art spec (frames, duration, loop, playing, scale) as flat
-- custom properties on res/entities/*.tj. These become the single source of
-- truth: the entity .lua builds its Sprite{} from the merged object.properties
-- instead of hard-coded res/img paths. The art's image is NOT a duplicated
-- property -- it comes from the template's inline tileset tile (the exact
-- reference the editor previews), exposed by the loader as `tilesetImage`
-- (file-typed values come back converted to project-root-relative res/img/...
-- paths by tj_template.lua). This test pins the exact values the templates
-- must carry.
local TjTemplate = require('src.map.tj_template')

-- tj, type, tileset image (converted), frames, duration, loop, playing, scaleX, scaleY
local SPRITE_SPECS = {
	{ tj = 'res/entities/teleport.tj',         type = 'teleport',         image = 'res/img/entity_teleporter.png',     frames = 1 },
	{ tj = 'res/entities/exit_door.tj',        type = 'exit_door',        image = 'res/img/entity_exit_door.png',      frames = 2,   duration = 1.0,     loop = false },
	{ tj = 'res/entities/switch.tj',           type = 'switch',           image = 'res/img/entity_switch.png',         frames = 5,   duration = 0.4,     loop = false },
	{ tj = 'res/entities/story.tj',            type = 'story',            image = 'res/img/entity_wood_sign_post.png', frames = 1 },
	{ tj = 'res/entities/spawn.tj',            type = 'spawn',            image = 'res/img/default.png',               frames = 1 },
	{ tj = 'res/entities/replicator.tj',       type = 'replicator',       image = 'res/img/entity_replicator.png',     frames = 1 },
	{ tj = 'res/entities/push_box.tj',         type = 'push_box',         image = 'res/img/pushable_crate_wood.png',   frames = 1 },
	{ tj = 'res/entities/drawbridge.tj',       type = 'drawbridge',       image = 'res/img/entity_drawbridge.png',     frames = 4,   duration = 0.3,     loop = false, playing = false },
	{ tj = 'res/entities/coin.tj',             type = 'coin',             image = 'res/img/coins.png',                 frames = 8,   duration = 1.0, loop = true, playing = true, scaleX = 0.8, scaleY = 0.8 },
	{ tj = 'res/entities/mover_platform.tj',   type = 'mover_platform',   image = 'res/img/entity_mover_platform.png', frames = 1 },
	{ tj = 'res/entities/cage.tj',             type = 'cage',             image = 'res/img/cage/cage.png',             frames = 2,   duration = 1.0,     loop = false },
	{ tj = 'res/entities/ladder.tj',           type = 'ladder',           image = 'res/img/ladder.png',                frames = 4,   duration = 1.0,     loop = false },
	{ tj = 'res/entities/boulder.tj',          type = 'boulder',          image = 'res/img/pushable_stone_block.png',  frames = 1 },
	{ tj = 'res/entities/key.tj',              type = 'key',              image = 'res/img/entity_key.png',            frames = 1 },
	{ tj = 'res/entities/flag.tj',             type = 'flag',             image = 'res/img/entity_flag.png',           frames = 1 },
	{ tj = 'res/entities/jump_pad.tj',         type = 'jump_pad',         image = 'res/img/entity_jump_pad.png',       frames = 3,   duration = 0.2,     loop = false, playing = false },
	{ tj = 'res/entities/blocker.tj',          type = 'blocker',          image = 'res/img/entity_blocker.png',        frames = 48,  duration = 2.0,     loop = false, playing = false },
	{ tj = 'res/entities/pressure_switch.tj',  type = 'pressure_switch',  image = 'res/img/entity_pressure_switch.png', frames = 1 },
}

test('every sprite-bearing template advertises its art spec as props', function()
	for _, spec in ipairs(SPRITE_SPECS) do
		local template = TjTemplate.resolve(spec.tj)

		local byName = {}
		for _, prop in ipairs(template.object.properties) do
			byName[prop.name] = prop
		end

		assertEqual(spec.type, template.object.type, spec.tj .. ' type mismatch')
		assertEqual(spec.image, template.tilesetImage, spec.tj .. ' tileset image')
		assertEqual(spec.frames, byName.frames.value, spec.tj .. ' frames')
		if spec.duration ~= nil then
			assertEqual(spec.duration, byName.duration.value, spec.tj .. ' duration')
		end
		if spec.loop ~= nil then
			assertEqual(spec.loop, byName.loop.value, spec.tj .. ' loop')
		end
		if spec.playing ~= nil then
			assertEqual(spec.playing, byName.playing.value, spec.tj .. ' playing')
		end
		if spec.scaleX ~= nil then
			assertEqual(spec.scaleX, byName.scaleX.value, spec.tj .. ' scaleX')
			assertEqual(spec.scaleY, byName.scaleY.value, spec.tj .. ' scaleY')
		end
	end
end)

test('layered_prop carries no sprite props (genuine non-sprite template)', function()
	local layered = TjTemplate.resolve('res/entities/layered_prop.tj')
	for _, prop in ipairs(layered.object.properties) do
		local name = prop.name
		assertFalse(name == 'image' or name == 'frames' or name == 'scaleX', 'layered_prop has sprite prop ' .. name)
	end
end)

test('mover_platform behavioral prop is endBehavior (not the endBehaviour typo)', function()
	local template = TjTemplate.resolve('res/entities/mover_platform.tj')
	local byName = {}
	for _, prop in ipairs(template.object.properties) do
		byName[prop.name] = prop
	end
	assertEqual('pingpong', byName.endBehavior.value)
	assertEqual(nil, byName.endBehaviour, 'endBehaviour typo should be gone')
	assertEqual(50, byName.speed.value)
	assertEqual(0.5, byName.pause.value)
end)

test('behavioral props survive alongside sprite props', function()
	local switchT = TjTemplate.resolve('res/entities/switch.tj')
	local switchByName = {}
	for _, prop in ipairs(switchT.object.properties) do
		switchByName[prop.name] = prop
	end
	assertEqual('43', switchByName.target.value, 'switch target')

	local cageT = TjTemplate.resolve('res/entities/cage.tj')
	local cageByName = {}
	for _, prop in ipairs(cageT.object.properties) do
		cageByName[prop.name] = prop
	end
	assertEqual('red', cageByName.color.value, 'cage color')

	local replicaT = TjTemplate.resolve('res/entities/replicator.tj')
	local replicaByName = {}
	for _, prop in ipairs(replicaT.object.properties) do
		replicaByName[prop.name] = prop
	end
	assertEqual('push_box', replicaByName.spawnType.value, 'replicator spawnType')
	assertEqual(1, replicaByName.maxSpawns.value, 'replicator maxSpawns')

	local bridgeT = TjTemplate.resolve('res/entities/drawbridge.tj')
	local bridgeByName = {}
	for _, prop in ipairs(bridgeT.object.properties) do
		bridgeByName[prop.name] = prop
	end
	assertEqual(false, bridgeByName.flipCrossing.value, 'drawbridge flipCrossing')
	-- editor-first authoring values (see NOTES.md 'Sprite offsets'): the art
	-- box and the one-tile deck are independent; pinning them here guards
	-- the loader-level defaults the fixtures/maps inherit.
	assertEqual(-64, bridgeByName.spriteOffsetY.value, 'drawbridge spriteOffsetY')
	assertEqual(32, bridgeByName.colliderOffsetX.value, 'drawbridge colliderOffsetX')
	assertEqual(-32, bridgeByName.colliderOffsetY.value, 'drawbridge colliderOffsetY')
	assertEqual(32, bridgeByName.colliderWidth.value, 'drawbridge colliderWidth')
	assertEqual(32, bridgeByName.colliderHeight.value, 'drawbridge colliderHeight')

	local blockerT = TjTemplate.resolve('res/entities/blocker.tj')
	local blockerByName = {}
	for _, prop in ipairs(blockerT.object.properties) do
		blockerByName[prop.name] = prop
	end
	assertEqual(-6, blockerByName.spriteOffsetY.value, 'blocker spriteOffsetY')

	local flagT = TjTemplate.resolve('res/entities/flag.tj')
	local flagByName = {}
	for _, prop in ipairs(flagT.object.properties) do
		flagByName[prop.name] = prop
	end
	assertEqual('red', flagByName.color.value, 'flag color')
	assertEqual(2, flagByName.spriteOffsetY.value, 'flag spriteOffsetY')
end)