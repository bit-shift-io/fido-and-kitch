local Log = require('src.utils.log')

local Ladder = Class{__includes = Entity}

-- Per-rung tile objects (authoring model):
--
-- Each rung is a 32x32 bottom-anchored gid tile object (object.y = BOTTOM
-- edge). The entity_factory pre-pass (annotateLadders) folds a vertically
-- contiguous column of rungs with matching custom properties into one
-- logical ladder: every rung is tagged with the shared `ladderFamily` rect
-- (the merged bottom-anchored union), and the lowest rung is flagged
-- `leadRung`.
--
-- Only the lead rung builds an entity: one static sensor collider for the
-- whole ladder plus the tiled sprite stack. The upper rungs become thin
-- aliases -- no collider, no sprites -- exposing isLadder and a pointer to
-- the lead so any rung's object id works as a switch target.
--
-- All rect math is BOTTOM-anchored: rect.y is the bottom edge, the top edge
-- is rect.y - rect.height. resizeTileHeight/grow raise the top edge and
-- never move the bottom.
function Ladder:init(object, map)
	Entity.init(self, object, 'ladder')
	self.isLadder = true
	self.map = map
	self.family = object.ladderFamily or object
	self.rect = self.family
	self.lead = nil

	if object.leadRung then
		self:createCollider()
		self:createSprites()
		self.lead = self
		self.family.entity = self
	else
		-- thin alias -- the lead collider/sprites already cover this column
		self.lead = self.family.entity
		self.collider = self.lead and self.lead.collider or nil
	end
end

-- Aliases created before their lead (map object order is not guaranteed)
-- resolve the pointer lazily on the first update.
function Ladder:update(dt)
	if self.lead == nil and self.family and self.family.entity then
		self.lead = self.family.entity
		self.collider = self.lead.collider
	end
	Entity.update(self, dt)
end

function Ladder:leadEntity()
	return self.lead or self
end

function Ladder:tileHeight()
	return self.rect.height / self.map.tileheight
end

-- The collider is (re)built from the current rect. Bottom-anchored: the
-- collider's top sits on rect.y - rect.height, its bottom on rect.y.
function Ladder:createCollider()
	self:removeComponent(self.collider)
	if self.collider and self.collider.destroy then
		self.collider:destroy()
	end

	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=Rect.shapeArgs(self.rect.width, self.rect.height),
		body_type='static',
		sensor=true,
		position=Vector(self.rect.x + self.rect.width * 0.5, self.rect.y - self.rect.height * 0.5),
		entity=self
	})
	return self.collider
end

-- side 'top' (default): raise the top edge, bottom edge stays fixed.
-- side 'bottom': lower the bottom edge, top edge stays fixed.
function Ladder:resizeTileHeight(newTileHeight, side)
	Log.debug('resize height to '..newTileHeight)

	local newHeight = (newTileHeight * self.map.tileheight)
	local heightDelta = newHeight - self.rect.height
	self.rect.height = newHeight
	if side == 'bottom' then
		self.rect.y = self.rect.y + heightDelta
	end

	self:createCollider()
	self:createSprites()
end

function Ladder:grow(tileHeight, side)
	local lead = self:leadEntity()
	if lead == self then
		self:resizeTileHeight(self:tileHeight() + tileHeight, side)
	else
		lead:grow(tileHeight, side)
	end
end

function Ladder:createSprites()
	local tileHeight = self:tileHeight()

	if self.sprites then
		for _, sprite in pairs(self.sprites) do
			self:removeComponent(sprite)
		end
	end

	self.sprites = {}
	-- bottom-anchored: top edge is rect.y - rect.height; tiles stack downward
	local top = self.rect.y - self.rect.height
	for i = 0, (tileHeight - 1), 1 do
		local rect = Rect{x=self.rect.x, y=top + (i * self.map.tileheight), width=self.map.tilewidth, height=self.map.tileheight}
		local sprite = self:addComponent(Sprite{
			image='res/img/ladder.png',
			frames=4,
			duration=1.0,
			loop=false,
			position=rect:centre(),
			shape_arguments=rect:colliderShapeArgs(),
		})
		sprite.timeline:play()
		table.insert(self.sprites, sprite)
	end
end

-- Switch off hides the ladder (removes collider + sprites, rect unchanged)
-- so climbing stops; switch on restores everything, keeping any grown size.
-- Aliases forward straight to the lead so any rung id works as a target.
function Ladder:switch(switch, user)
	local lead = self:leadEntity()
	if lead == self then
		if switch.state == 'off' then
			self:hide()
		elseif switch.state == 'on' then
			self:show()
			if self.object and self.object.exec then
				self.object:exec('switchOn', self)
			end
		end
	else
		lead:switch(switch, user)
	end
end

function Ladder:hide()
	self.hidden = true
	self:removeComponent(self.collider)
	if self.collider and self.collider.destroy then
		self.collider:destroy()
	end
	self.collider = nil
	for _, sprite in pairs(self.sprites or {}) do
		self:removeComponent(sprite)
	end
	self.sprites = nil
end

function Ladder:show()
	self.hidden = false
	self:createCollider()
	self:createSprites()
end

return Ladder