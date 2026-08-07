local Log = require('src.utils.log')
local EventBus = require('src.utils.event_bus')

local Cage = Class{__includes = Entity}

function Cage:init(object, map)
	Entity.init(self, object, 'cage')
	local color = object.properties.color
	local position = Rect.centreOfMapObject(object)

	-- visual footprint only -- the collider below stays the map's 1x1 tile;
	-- the bigger sprites are purely decorative bleed so the art can extend
	-- beyond the tile the cage sits on
	local sprite_shape_arguments = Rect.shapeArgs(object.width * 2, object.height * 2)
	self.sprite = self:addComponent(Sprite{
		image='res/img/cage/cage.png',
		frames=2,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=sprite_shape_arguments,
	})
	self.lockSprite = self:addComponent(Sprite{
		image=string.format('res/img/cage/cage_lock_%s.png', color),
		frames=1,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=sprite_shape_arguments,
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments={0, 0, 32, 32},
		body_type='static',
		sensor=true,
		position=position
	})
	
	self:addComponent(Usable{
		entity=self,
		use=utils.bindSelf(self.use, self),
		requiredItem=string.format('key_%s', color)
	})

	self.sound = self:addComponent(Sound{
		sounds = {
			open = 'res/snd/entity_cage_open.wav'
		}
	})

	-- Store spawn params; NPC is spawned when the cage is opened, not on map load
	local spawnTypeMap = {
		bird = 'npc_bird',
		rabbit = 'npc_rabbit',
	}
	local spawnType = object.properties.spawn_type or object.properties.actor or 'bird'
	local npcType = spawnTypeMap[spawnType] or spawnType
	
	-- Let entity type defaults define NPC sprite dimensions
	-- (bird=155x155, rabbit=142x137, etc.)
	local npcProps = {properties = {}}
	
	-- Spawn the NPC at the cage's own position (Tiled tile objects are
	-- bottom-edge anchored, so preserve gid for Rect.centreOfMapObject)
	npcProps.x = object.x
	npcProps.y = object.y
	npcProps.gid = object.gid
	
	self.spawnNpcType = npcType
	self.spawnLayer = object.layer
	self.spawnNpcProps = npcProps
	self.map = map
end

function Cage:use(user)
	Log.debug('Cage has been used')
	self:removeComponent(self.lockSprite)
	self.sprite.timeline:play()
	self.sound:play('open')

	EventBus.emit('cage_unlocked', {cage = self})

	-- Spawn the NPC on first use
	if self.actor == nil and self.spawnNpcType then
		self.actor = self.map:loadEntity(self.spawnNpcType, self.spawnLayer, self.spawnNpcProps)
	end

	if self.actor == nil then
		return
	end
	-- Set the NPC to follow the player who opened the cage
	if self.actor.setTarget then
		self.actor:setTarget(user)
	end
end

return Cage