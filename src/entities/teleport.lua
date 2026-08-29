local Teleport = Class{__includes = Entity}
local TeleportTrail = require('src.fx.teleport_trail')
local TeleportBurst = require('src.fx.teleport_burst')
local SpriteProps = require('src.entities.sprite_props')

function Teleport:init(object, map)
	Entity.init(self, object, 'teleport')
	self.map = map
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	self.target = object.properties.target and map:getObjectById(object.properties.target.id)

	-- The sprite fills the authored object's own rect, 1:1 -- like the
	-- blocker. The template (teleport.tj) is authored at the art size, so
	-- the object box IS the visual footprint; no 2x box and no lift. The
	-- use sensor follows the same rect (bottom-flush): the teleporter reads
	-- at its art footprint rather than a 1x1 tile. Optional `spriteOffsetY`
	-- (px, positive = down) nudges only the art, tuned from the running
	-- game.
	local spriteOffsetY = tonumber(object.properties.spriteOffsetY) or 0
	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.shape_arguments = shape_arguments
	spriteProps.position = position + Vector(0, spriteOffsetY)
	self.sprite = self:addComponent(Sprite(spriteProps))
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=shape_arguments,
		body_type='static',
		enter=utils.bindSelf(Teleport.contact, self),
		sensor=true,
		position=position
	})
	-- Defaults to enabled, matching every existing map (none author this
	-- property) -- an authored `enabled=false` lets a level start this
	-- teleporter blocked until a switch/pressure-plate targeting it turns
	-- it on, rather than always starting usable.
	local startEnabled = (object.properties.enabled == nil) and true or object.properties.enabled
	self.usable = self:addComponent(Usable{
		entity=self,
		use=utils.bindSelf(self.use, self),
		enabled=startEnabled
	})
	self:addComponent(Switchable{
		entity=self,
		enabled=startEnabled,
		onStateChange=function(enabled)
			self.usable.enabled = enabled
		end
	})

	-- only one teleport sound asset exists (res/snd/); both directions share it
	self.sound = self:addComponent(Sound{
		sounds = {
			['in'] = 'res/snd/entity_teleport.wav',
			out = 'res/snd/entity_teleport.wav',
		}
	})
end

function Teleport:contact(other)

end


function Teleport:use(user)
	if self.target then
		self.sound:play('in')

		-- Calculate travel parameters
		local user_bounds = user.collider:getBounds()
		local startX = user.collider:getX()
		local startY = user.collider:getY()
		
		local t_x = self.target.x + self.target.width * 0.5
		local t_y = self.target.y
		local destX = t_x
		local destY = t_y - user_bounds.height * 0.5
		
		local dx = destX - startX
		local dy = destY - startY
		local dist = math.sqrt(dx*dx + dy*dy)
		
		-- Generate curve and calculate duration
		local curve = TeleportTrail.generateCurve({x = startX, y = startY}, {x = destX, y = destY})
		local duration = TeleportTrail.calculateTravelDuration(dist)
		
		-- Spawn ENTRY burst at source
		if self.map and self.map.fx then
			self.map.fx:add(TeleportBurst{
				position = {x = startX, y = startY},
			})
		end
		
		-- Spawn travel particle effect
		if self.map and self.map.fx then
			self.map.fx:add(TeleportTrail{
				curve = curve,
				duration = duration,
				start = {x = startX, y = startY},
				dest = {x = destX, y = destY},
			})
		end
		
		-- Get camera from InGameState for tracking during travel
		local camera = nil
		if game and game.fsm and game.fsm.currentState and game.fsm.currentState.camera then
			camera = game.fsm.currentState.camera
		end
		
		-- Enter travel state on player
		user.fsm:setState('TeleportTravelState', {
			curve = curve,
			duration = duration,
			destX = destX,
			destY = destY,
			camera = camera,
			sourceTeleport = self,
			targetTeleport = self.target.entity,
		})
		
		-- Play exit sound at destination
		if self.target.entity then
			self.target.entity.sound:play('out')
		end
	end
end


return Teleport
