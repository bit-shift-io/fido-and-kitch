local Log = require('src.utils.log')

local Ladder = Class{__includes = Entity}

-- Thickness of the standable one-way slab at the ladder's top edge.
local TOP_THICKNESS = 8
-- How far below the top a player counts as "under the deck" and may pass
-- through it (same tolerance the mover platform's one-way deck uses).
local LAND_TOL = 6

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
		self:createTopCollider()
		self:createSprites()
		self.lead = self
		self.family.entity = self
	else		-- thin alias -- the lead collider/sprites already cover this column
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

-- The bare top of the ladder is a standable one-way platform (see NOTES.md
-- 2026-08-24 decision 4): a thin solid slab sitting on the top edge so a
-- player who climbs out of the volume -- or walks across from an adjacent
-- flush ledge -- can stand there with no terrain beneath.
function Ladder:createTopCollider()
	self:removeTopCollider()

	local topEdge = self.rect.y - self.rect.height
	self.topCollider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=Rect.shapeArgs(self.rect.width, TOP_THICKNESS),
		body_type='static',
		sensor=false,
		position=Vector(self.rect.x + self.rect.width * 0.5, topEdge + TOP_THICKNESS * 0.5),
		entity=self
	})
	-- Entity-owned colliders are not ground by default; opt in so
	-- queryOnGround treats the slab as something to stand and walk on.
	self.topCollider.walkable = true

	-- One-way top-only collision, same shape as the mover platform's deck:
	-- a player whose feet sit more than LAND_TOL below the top is under it
	-- -> 'cross'; at the top -> 'slide' (land, stand, be held). Anyone else
	-- returns nil -> global World.colFilter defaults apply unchanged.
	-- A player currently climbing this ladder always gets 'cross' so the
	-- climb-through works and LadderState's own sensor-based exit decides
	-- when they step out onto the slab. Falls from above deliberately do
	-- NOT cross: the ground-probe lands a falling player on the slab
	-- (perch-on-top), while falls that begin already inside the volume --
	-- under the top plane -- are caught by the no-gravity zone.
	local slab = self.topCollider
	local function topColFilter(a, b)
		local other = (a == slab) and b or a
		local entity = other.entity
		if entity and entity.type == 'player' then
			local state = entity.fsm and entity.fsm.currentState
			if state and state.name == 'LadderState' then
				return 'cross'
			end
			local feet = other.y + other.height
			if feet > slab.y + LAND_TOL then
				return 'cross'
			end
			return 'slide'
		end
		return nil
	end
	self.topCollider:setColFilterFn(topColFilter)
end

function Ladder:removeTopCollider()
	if self.topCollider then
		self:removeComponent(self.topCollider)
		if self.topCollider.destroy then
			self.topCollider:destroy()
		end
		self.topCollider = nil
	end
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
	self:createTopCollider()
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
	self:removeTopCollider()
	for _, sprite in pairs(self.sprites or {}) do
		self:removeComponent(sprite)
	end
	self.sprites = nil
end

function Ladder:show()
	self.hidden = false
	self:createCollider()
	self:createTopCollider()
	self:createSprites()
end

return Ladder