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
--
-- Single file, not the multi-file directory NOTES.md originally called for:
-- that split existed solely so the pure decision helpers below could be
-- required from tests/unit/, which couldn't construct a Sprite/Collider-
-- composing entity headless. tests/support/headless_bootstrap.lua now makes
-- that construction possible directly (NOTES.md also records how this
-- reversed the drawbridge's identical split), so the helpers stay private
-- locals here instead of a separate _support module. See
-- tests/unit/pressure_switch_test.lua for the entity-level tests this enables.

local PressureSwitch = Class{__includes = Entity}

-- How far a weight's centre-x may sit from the plate tile's centre and still
-- count as being on it. "Substantially on it" (DECISIONS Q11): merely
-- overlapping the plate is not enough -- a box resting with one edge barely
-- over the plate is not standing on it, and neither is a player brushing past
-- the edge. A quarter of a tile each way is generous enough to feel fair while
-- still requiring the weight to be recognisably seated.
local TOLERANCE = 8

local function isWeightOn(weightCentreX, plateCentreX)
	return math.abs(weightCentreX - plateCentreX) <= TOLERANCE
end

-- Whether the plate should be active next frame. The caller drives its target
-- whenever this differs from the current state, which is all the momentary vs
-- latching difference amounts to:
--   * momentary (default) follows the weight, so it transitions twice -- on
--     when the first weight arrives, off when the last one leaves -- and
--     re-drives the target both times
--   * latching never returns to off, so it transitions once and drives once
-- Presence is recomputed fresh every frame from whatever is currently on the
-- plate, so several weights count as one activation and it releases only when
-- the last of them leaves, with no occupancy bookkeeping to get out of step.
local function nextActivation(isActive, latching, weightPresent)
	if isActive and latching then
		return true
	end

	return weightPresent
end

-- the 1x1 tile directly above the plate: a weight standing on it has its feet
-- (collider bottom) somewhere in that tile, which is all "on the plate" needs
-- to mean -- unlike the drawbridge, this plate is exactly one tile wide/tall
-- so its occupancy zone doesn't need extra headroom.
local OCCUPANCY_HEIGHT_MARGIN = 32

-- placeholder art: a flat plate quad that changes colour when active. Real art
-- is out of scope for this feature (DECISIONS Q14); the props use real images
-- because they already had some, and no plate art exists.
local PLATE_HEIGHT = 6
local COLOUR_INACTIVE = {0.45, 0.45, 0.5}
local COLOUR_ACTIVE = {0.35, 0.85, 0.45}

function PressureSwitch:init(object, map)
	Entity.init(self, object, 'pressure_switch')
	self.state = 'off'
	self.latching = (object.properties and object.properties.latching) or false
	-- lets a pushable recognise this as something to seat itself on
	self.isPressurePlate = true

	-- object.y from Tiled is top-anchored for a hand-drawn plain rectangle but
	-- BOTTOM-anchored for a tile object (has a gid -- what dragging the
	-- res/entities/pressure_switch.tj template from Tiled's palette
	-- produces), same split as PushableSupport.spawnCentre. Both shapes exist
	-- across this project's maps for pressure_switch: res/map/fab2.tmj places
	-- gid template instances, tests/fixtures/pressure_switch_room.tmj hand-
	-- authors plain rectangles.
	local topLeftY = object.gid and (object.y - object.height) or object.y
	self.rect = Rect{x = object.x, y = topLeftY, width = object.width, height = object.height}
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
	if isWeightOn(propCentreX, self.plateCentreX) then
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
			if isWeightOn(collider:getX(), self.plateCentreX) then
				return true
			end
		end
	end

	return false
end

function PressureSwitch:update(dt)
	Entity.update(self, dt)

	local wasActive = self:isActive()
	local isActive = nextActivation(wasActive, self.latching, self:hasWeight())

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

	if self.target.entity then
		local switchable = self.target.entity.getComponent and self.target.entity:getComponent(Switchable)
		if switchable then
			switchable:switch(self, nil)
		elseif self.target.entity.switch then
			self.target.entity:switch(self, nil)
		end
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

-- White-box seam for tests/unit/pressure_switch_test.lua only, mirroring
-- Drawbridge._internal (see NOTES.md). Not for use by production code --
-- reach for the real entity there.
PressureSwitch._internal = {
	isWeightOn = isWeightOn,
	nextActivation = nextActivation,
}

return PressureSwitch
