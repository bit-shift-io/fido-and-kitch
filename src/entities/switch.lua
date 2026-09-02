local Log = require("src.utils.log")
local SpriteProps = require("src.entities.sprite_props")

local Switch = Class({ __includes = Entity })

function Switch:init(object, map)
	Entity.init(self, object, "switch")
	self.state = "off"
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = position
	spriteProps.shape_arguments = shape_arguments
	self.sprite = self:addComponent(Sprite(spriteProps))
	self.collider = self:addComponent(Collider({
		shape_type = "rectangle",
		shape_arguments = shape_arguments,
		body_type = "static",
		position = position,
		sensor = true,
	}))
	self:addComponent(Usable({
		entity = self,
		use = utils.bindSelf(self.use, self),
	}))

	-- only one toggle sound asset exists (res/snd/); both directions share it
	self.sound = self:addComponent(Sound({
		sounds = {
			on = "res/snd/entity_switch_toggle.wav",
			off = "res/snd/entity_switch_toggle.wav",
		},
	}))

	self.target = map:getObjectById(object.properties.target.id)

	-- lets a level designer place a switch already flipped on: appears
	-- instantly in its 'on' pose, no animation or sound, no target sync
	-- (the target's own initial state is set independently on itself)
	if object.properties.startOn then
		self.state = "on"
		self.sprite:snapToEnd()
	end
end

function Switch:use(user)
	Log.debug("switch has been used")

	if self.state == "off" then
		self.state = "on"
		self.sprite:playForward()
	else
		self.state = "off"
		self.sprite:playReverse()
	end
	self.sound:play(self.state)

	if self.target.entity then
		local switchable = self.target.entity.getComponent and self.target.entity:getComponent(Switchable)
		if switchable then
			switchable:switch(self, user)
		elseif self.target.entity.switch then
			self.target.entity:switch(self, user)
		end
	end
end

return Switch
