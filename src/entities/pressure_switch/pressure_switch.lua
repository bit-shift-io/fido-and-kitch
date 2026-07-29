-- A weight-activated plate: it turns on while a qualifying weight (a player or
-- a pushable prop) is substantially on it, and drives a target entity through
-- exactly the same `target` + `:switch()` mechanism the lever switch uses
-- (src/entities/switch.lua). The difference from that lever is only the
-- TRIGGER -- presence polled every frame rather than a player pressing "use" --
-- so `self.state` is kept in the same 'on'/'off' shape the targets read
-- (Ladder:switch checks `switch.state == 'on'`).
--
-- Occupancy is recomputed fresh every frame with no memory of who was here
-- before, the same approach src/entities/drawbridge uses: several weights
-- therefore count as one activation and the plate releases only when the last
-- of them leaves, with no bookkeeping to fall out of step.
local PressureSwitchSupport = require('src.entities.pressure_switch.pressure_switch_support')

local PressureSwitch = Class{__includes = Entity}

-- tall enough to catch a weight resting on the plate -- feet on its top edge,
-- body extending upward out of the plate's own depth -- mirroring the
-- drawbridge's occupancy margin
local OCCUPANCY_HEIGHT_MARGIN = 200

-- placeholder art: a flat plate quad that changes colour when active. Real art
-- is out of scope for this feature (DECISIONS Q14); the props use real images
-- because they already had some, and no plate art exists.
local PLATE_HEIGHT = 6
local COLOUR_INACTIVE = {0.45, 0.45, 0.5}
local COLOUR_ACTIVE = {0.35, 0.85, 0.45}

function PressureSwitch:init(object)
	Entity.init(self)
	self.type = 'pressure_switch'
	self.object = object
	self.name = object.name
	self.state = 'off'
	self.latching = (object.properties and object.properties.latching) or false
	-- lets a pushable recognise this as something to seat itself on
	self.isPressurePlate = true

	self.rect = Rect(object)
	local position = self.rect:centre()
	self.plateCentreX = position.x

	-- a sensor: weights rest on the ground/floor it sits on and cross the
	-- plate freely rather than being blocked or held up by it
	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = self.rect:colliderShapeArgs(),
		body_type = 'static',
		sensor = true,
		position = position,
	})

	-- resolved the same way src/entities/switch.lua resolves its own target
	if object.properties and object.properties.target then
		self.target = map:getObjectById(object.properties.target.id)
	end

	-- no assets yet at res/snd/entity_pressure_{press,release}.wav;
	-- Sound:play warns and skips until they're added
	self.sound = self:addComponent(Sound{
		sounds = {
			press = 'res/snd/entity_pressure_press.wav',
			release = 'res/snd/entity_pressure_release.wav',
		}
	})
end

function PressureSwitch:isActive()
	return self.state == 'on'
end

-- Where a prop at this centre-x should seat itself, or nil if it is not close
-- enough to seat at all. A pushable asks this when the player stops pushing it
-- (see Pushable:seatOnPlate); the plate owns the tolerance so the prop never
-- has to know what "substantially on it" means.
function PressureSwitch:seatCentreX(propCentreX)
	if PressureSwitchSupport.isWeightOn(propCentreX, self.plateCentreX) then
		return self.plateCentreX
	end

	return nil
end

-- anything currently substantially on the plate: players and pushable props
-- qualify, nothing else does
function PressureSwitch:hasWeight()
	local bounds = {
		left = self.rect.x,
		right = self.rect.x + self.rect.width,
		top = self.rect.y - OCCUPANCY_HEIGHT_MARGIN,
		bottom = self.rect.y + self.rect.height,
	}

	for _, collider in ipairs(world:queryOverlap(bounds)) do
		local entity = collider.entity
		if entity and entity ~= self and (entity.type == 'player' or entity.isPushable) then
			if PressureSwitchSupport.isWeightOn(collider:getX(), self.plateCentreX) then
				return true
			end
		end
	end

	return false
end

function PressureSwitch:update(dt)
	Entity.update(self, dt)

	local wasActive = self:isActive()
	local isActive = PressureSwitchSupport.nextActivation(wasActive, self.latching, self:hasWeight())

	if isActive == wasActive then
		return
	end

	self.state = isActive and 'on' or 'off'
	self.sound:play(isActive and 'press' or 'release')
	self:driveTarget()
end

-- mirrors src/entities/switch.lua: the target reads this switch's `state`
function PressureSwitch:driveTarget()
	if self.target == nil or self.target.entity == nil then
		return
	end

	if self.target.entity.switch then
		self.target.entity:switch(self, nil)
	end
end

function PressureSwitch:draw()
	Entity.draw(self)

	local colour = self:isActive() and COLOUR_ACTIVE or COLOUR_INACTIVE
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(colour[1], colour[2], colour[3], 1)
	love.graphics.rectangle(
		'fill',
		self.rect.x,
		self.rect.y + self.rect.height - PLATE_HEIGHT,
		self.rect.width,
		PLATE_HEIGHT
	)
	love.graphics.setColor(r, g, b, a)
end

return PressureSwitch
