-- A destructible tile: a plain solid obstacle -- a wall-facing or
-- floor-facing tile authored as a Tiled object, matching whichever of
-- res/entities/destructible_tile_wall.tj / destructible_tile_floor.tj was
-- placed -- that blocks a laser beam like any other opaque prop
-- (src/entities/laser_beam_resolver.lua's default "anything else
-- non-sensor is opaque" rule) until a fully-on beam destroys it.
--
-- Destroy-on-beam-hit needs NO code here, mirroring src/entities/
-- boulder.lua's own header: src/entities/laser_beam_resolver.lua's
-- isDestructible(entity) also matches `entity.type == 'destructible_tile'`
-- now (the boulder's existing hook extended, not duplicated -- see that
-- module's comment), and src/entities/laser.lua's already-generic destroy
-- loop (`destroyedEntity:queueDestroy()`, gated on `self:isFullyOn()`)
-- calls it exactly like it does for a boulder. Removal is the same generic
-- Entity path every destroyed entity uses (src/entity.lua's
-- queueDestroy/destroy -> Collider:destroy(), which pulls it out of the
-- bump world) -- nothing tile-specific, and "reveals the background art"
-- needs no special-case code either, since the map's background layer is
-- already drawn beneath every object layer.
--
-- Two art variants share this one file (res/entities/destructible_tile_
-- wall.tj, res/entities/destructible_tile_floor.tj -- the first entity
-- type in this project to ship two templates for one type), both
-- declaring `"type": "destructible_tile"` in their object stanza -- the
-- template picks wall-facing vs floor-facing art per placed instance, the
-- same way SpriteProps.fromObject already drives every other prop's art
-- from its (possibly template-merged) properties.
--
-- Purely reactive on its own update(dt) -- no Switchable, no target, nothing
-- to decide per frame, so there is no update() here at all; Entity's own
-- default update(dt) (looping its components) is everything this needs, same
-- as src/entities/kill_zone.lua.
--
-- Optional chain-break cascade: a Tiled bool property `chainBreak` on an
-- instance means that when THIS tile is destroyed (by a beam or by being
-- force-destroyed as somebody else's neighbor), every destructible_tile
-- orthogonally touching its former tile-grid position is force-destroyed
-- ~0.3s later, regardless of THEIR own chainBreak setting.
--
-- A destroyed entity cannot run its own delayed timer via its own
-- update(dt): src/map/entity_factory.lua's layer:update detects
-- remove_from_map_flag, removes the entity from the layer's list, and calls
-- entity:destroy() all in the same pass that skips entity:update(dt) for a
-- flagged entity -- there is no frame where a queued-for-destruction tile
-- still gets ticked. So the cascade timer cannot live on the tile itself; it
-- lives in the map's FxManager (src/fx/manager.lua), which is exactly the
-- "outlives the entity that spawned it" registry this needs and already
-- ticks/reaps anything shaped {update, draw, done}.
--
-- The recursive part of the cascade needs no special-case code at all:
-- DestructibleTile:destroy() is overridden below to schedule a cascade timer
-- whenever `self.chainBreak` is set. A force-destroyed neighbor that is
-- itself chainBreak-enabled goes through this SAME override when the map's
-- normal removal pipeline eventually calls its own :destroy() (queueDestroy()
-- -> next layer:update pass -> entity:destroy()), so it schedules its own
-- timer for its own neighbors purely by going through the same code path a
-- directly-beamed tile does. A plain neighbor just finds self.chainBreak
-- false and does nothing further.
local SpriteProps = require("src.entities.sprite_props")
local TileShatter = require("src.fx.tile_shatter")
local BeamContactDelay = require("src.components.beam_contact_delay")

-- ~0.3s fixed delay between a chainBreak tile's destruction and its
-- neighbors being force-destroyed, driven by a dt accumulator (not a frame
-- count) like every other timer in this codebase (see Blocker's
-- OPENING_DURATION). Was 0.1s; bumped up because a whole chain resolving
-- within a couple of frames read as instant rather than a cascade.
local CHAIN_DELAY = 0.5

-- Delay between a fully-on beam first touching this tile and it actually
-- destroying, driven by the BeamContactDelay component below -- separate
-- from CHAIN_DELAY (same value today, but the two may diverge later: one
-- times "beam to destruction", the other times "destruction to cascade").
local DESTROY_DELAY = 0.5

-- The tile-grid cell a pixel position falls in, from the map's own tile size
-- -- not a fixed pixel offset -- so neighbor lookup works regardless of the
-- object's authored size.
local function gridPosition(x, y, tileWidth, tileHeight)
	return {
		x = math.floor(x / tileWidth),
		y = math.floor(y / tileHeight),
	}
end

-- Exactly one tile away on exactly one axis -- orthogonal, never diagonal,
-- never the same cell, never two-or-more tiles away.
local function isOrthogonalNeighbor(a, b)
	local dx = math.abs(a.x - b.x)
	local dy = math.abs(a.y - b.y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)
end

-- `tiles` is an array of {gridPosition = {x=,y=}, entity = <destructible_tile>}
-- for every currently-live destructible_tile. Returns the entities
-- orthogonally touching `originGrid`, regardless of their own chainBreak
-- setting -- force-destroy applies to any neighbor, not just chainBreak ones.
local function resolveChainNeighbors(originGrid, tiles)
	local neighbors = {}
	for _, tile in ipairs(tiles) do
		if isOrthogonalNeighbor(originGrid, tile.gridPosition) then
			table.insert(neighbors, tile.entity)
		end
	end
	return neighbors
end

-- dt-based accumulator, mirroring Blocker's openingTimer: returns the new
-- elapsed total and whether it has reached CHAIN_DELAY.
local function advanceTimer(elapsed, dt)
	local newElapsed = elapsed + dt
	return newElapsed, newElapsed >= CHAIN_DELAY
end

-- One-shot cascade timer, registered with the map's FxManager (map.fx:add)
-- so it keeps ticking after the tile that spawned it is gone. Shaped exactly
-- how FxManager expects: update(dt), draw() (no-op -- FxManager:draw() calls
-- it unconditionally), done() -> bool.
local ChainBreakTimer = {}
ChainBreakTimer.__index = ChainBreakTimer

function ChainBreakTimer.new(mapRef, originGrid)
	return setmetatable({
		mapRef = mapRef,
		originGrid = originGrid,
		elapsed = 0,
		finished = false,
	}, ChainBreakTimer)
end

function ChainBreakTimer:update(dt)
	if self.finished then
		return
	end

	local newElapsed, reached = advanceTimer(self.elapsed, dt)
	self.elapsed = newElapsed
	if reached then
		self:trigger()
		self.finished = true
	end
end

function ChainBreakTimer:trigger()
	local tiles = {}
	for _, entity in ipairs(self.mapRef:getEntitiesByType("destructible_tile")) do
		if entity.gridPosition then
			table.insert(tiles, { gridPosition = entity.gridPosition, entity = entity })
		end
	end

	for _, neighbor in ipairs(resolveChainNeighbors(self.originGrid, tiles)) do
		neighbor:queueDestroy()
	end
end

function ChainBreakTimer:done()
	return self.finished
end

-- no-op: FxManager:draw() calls this unconditionally on every active effect,
-- and this timer has no visual.
function ChainBreakTimer:draw() end

local DestructibleTile = Class({ __includes = Entity })

function DestructibleTile:init(object, mapRef)
	Entity.init(self, object, "destructible_tile")
	self.mapRef = mapRef
	self.chainBreak = (object.properties and object.properties.chainBreak) or false

	-- Bottom-anchored, like every other gid-template mounted fixture
	-- (boulder, blocker, mirror, laser_switch): object.y is the tile's
	-- BOTTOM edge, so the rect's top sits one height above it. A
	-- fixture-authored instance with no gid at all is still authored this
	-- way (see src/entities/laser.lua's own comment on the same point).
	local topLeftY = object.y - object.height
	self.rect = Rect({ x = object.x, y = topLeftY, width = object.width, height = object.height })
	local position = self.rect:centre()
	-- Kept on self (not just the local) so destroy() -- called after the
	-- collider/sprite are already gone -- still knows where to spawn the
	-- shatter fx.
	self.position = position

	-- Captured now, not derived later: once destroyed there is no entity
	-- left to ask "where was I". mapRef is optional (unit tests construct a
	-- bare tile with no map at all); a tile with no mapRef simply never
	-- schedules a cascade, which is fine since chainBreak also needs a map
	-- to look up neighbors.
	if self.mapRef and self.mapRef.map then
		local tileWidth = self.mapRef.map.tilewidth
		local tileHeight = self.mapRef.map.tileheight
		self.gridPosition = gridPosition(position.x, position.y, tileWidth, tileHeight)
	end

	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = position
	spriteProps.shape_arguments = self.rect:colliderShapeArgs()
	self.sprite = self:addComponent(Sprite(spriteProps))

	-- Solid collider matching the object rect exactly -- no thinning (unlike
	-- src/entities/blocker.lua's barrier fraction), no dynamic fall (unlike
	-- the boulder/push_box pushables): a destructible tile is a static
	-- obstacle until a fully-on beam destroys it.
	self.collider = self:addComponent(Collider({
		shape_type = "rectangle",
		shape_arguments = self.rect:colliderShapeArgs(),
		body_type = "static",
		sensor = false,
		position = position,
	}))
	-- Player:queryOnGround()/GroundSupport treat a bare `entity == nil`
	-- collider as terrain; this collider belongs to this DestructibleTile
	-- entity, so it needs an explicit opt-in to be recognised as ground a
	-- player can stand and walk on, or a player stepping onto a
	-- floor-mounted destructible tile gets stuck in FallState the instant
	-- they step onto it (same gotcha as src/entities/drawbridge.lua's deck).
	self.collider.walkable = true

	-- Drives the delay between a fully-on beam first touching this tile and
	-- it actually destroying: src/entities/laser.lua calls
	-- self.beamContactDelay:markContact() every frame a fully-on beam hits
	-- this tile instead of queueDestroy()-ing it directly.
	self.beamContactDelay = self:addComponent(BeamContactDelay({ delay = DESTROY_DELAY }))
end

-- Base cleanup first (collider/sprite removal, same as every other
-- destroyed entity), THEN a shatter burst at the tile's last known position
-- (every destruction, chain or direct -- unlike the cascade timer below,
-- which is chainBreak-only), THEN, only if this tile is chainBreak-enabled,
-- register a cascade timer with the map's FxManager so its neighbors get
-- force-destroyed ~0.3s later.
function DestructibleTile:destroy()
	Entity.destroy(self)

	if self.mapRef and self.mapRef.fx and self.position then
		self.mapRef.fx:burst(TileShatter, { x = self.position.x, y = self.position.y })
	end

	if self.chainBreak and self.mapRef and self.mapRef.fx and self.gridPosition then
		self.mapRef.fx:add(ChainBreakTimer.new(self.mapRef, self.gridPosition))
	end
end

-- White-box seam for tests/unit/destructible_tile_chain_test.lua only,
-- mirroring PressureSwitch._internal. Not for use by production code --
-- reach for the real entity there.
DestructibleTile._internal = {
	gridPosition = gridPosition,
	isOrthogonalNeighbor = isOrthogonalNeighbor,
	resolveChainNeighbors = resolveChainNeighbors,
	advanceTimer = advanceTimer,
	CHAIN_DELAY = CHAIN_DELAY,
	ChainBreakTimer = ChainBreakTimer,
}

return DestructibleTile
