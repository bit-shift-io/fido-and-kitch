local Log = require('src.utils.log')

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

	-- spawn the prisoner!
	if object.properties.path == nil then
		Log.warn('Cage has no path property setup for the actor to follow when released')
		return
	end

	local pathObj = map:getObjectById(object.properties.path.id)
	self.actor = map:loadEntity(object.properties.actor or 'bird', object.layer, pathObj)
end

function Cage:use(user)
	Log.debug('Cage has been used')
	self:removeComponent(self.lockSprite)
	self.sprite.timeline:play()
	self.sound:play('open')

	if self.actor == nil then
		return
	end
	self.actor:trigger()
end

return Cage