local Teleport = Class{__includes = Entity}
local TeleportTrail = require('src.fx.teleport_trail')
local TeleportBurst = require('src.fx.teleport_burst')
local SpriteProps = require('src.entities.sprite_props')
local PushableSupport = require('src.components.pushable.pushable_support')

-- Pushables aren't grid-locked (ADR 0001), and float residue from collision
-- resolution can leave a box resting a stray pixel or two into a
-- neighbouring tile rather than exactly flush against whatever stopped it.
-- A graze that shallow must not read as "the box is on this tile" -- so
-- overlap has to clear this depth before it counts.
local OVERLAP_TOLERANCE = 4

local function horizontalOverlap(a, b)
	return math.min(a.right, b.right) - math.max(a.left, b.left)
end

-- The single ground tile a teleporter actually stands on -- as opposed to
-- its full sensor/art footprint, which the comment in Teleport:init
-- deliberately authors at the art's own (possibly multi-tile) size so the
-- USE sensor reads across the whole sprite rather than a 1x1 tile
-- (`teleport.tj` is authored 64x64 -- 2x2 tiles). A pushable can never
-- physically be resting anywhere in that footprint except the one tile at
-- floor level, so tile-clearing must not treat the oversized sensor as "the
-- tile": a box resting a genuine tile away can still graze a 2x2 sensor's
-- extra overhang by more than any reasonable overlap tolerance, which is
-- exactly the bug this fixes. Horizontally centred within the footprint,
-- flush with its bottom edge (props stand on the floor, they don't float at
-- the sprite's full height) -- degrades to the full bounds unchanged for a
-- footprint that's already exactly one tile wide/tall.
local function groundTileBounds(bounds)
	local tileWidth = map.tilewidth
	local tileHeight = map.tileheight
	local centreX = (bounds.left + bounds.right) * 0.5

	return {
		left = centreX - tileWidth * 0.5,
		right = centreX + tileWidth * 0.5,
		top = bounds.bottom - tileHeight,
		bottom = bounds.bottom,
	}
end

-- Pushables (and only pushables -- DECISIONS.md Q1) overlapping the given
-- tile bounds by more than a graze, in the shape PushableSupport's checks
-- expect.
local function overlappingPushables(bounds)
	local found = {}
	for _, collider in ipairs(world:queryOverlap(bounds)) do
		local entity = collider.entity
		if entity and entity.isPushable and horizontalOverlap(bounds, entity.collider:getBounds()) > OVERLAP_TOLERANCE then
			table.insert(found, {entity = entity, centreX = entity.collider:getX()})
		end
	end
	return found
end

-- Whether the escape cell one tile beyond the source tile's edge, in the
-- given direction, is blocked -- by a wall (a collider with no entity, same
-- as terrain -- always solid, no graze tolerance) or by another pushable
-- genuinely resting there, not just grazing it (DECISIONS.md Q3: no chain
-- push). `excludeEntity` is the box being evaluated for the push itself: it
-- may straddle into the escape cell it would be pushed into, and must not
-- count as its own obstruction.
local function escapeCellBlocked(tileBounds, direction, excludeEntity)
	local width = tileBounds.right - tileBounds.left
	local probe
	if direction == 'left' then
		probe = {left = tileBounds.left - width, right = tileBounds.left, top = tileBounds.top, bottom = tileBounds.bottom}
	else
		probe = {left = tileBounds.right, right = tileBounds.right + width, top = tileBounds.top, bottom = tileBounds.bottom}
	end

	for _, collider in ipairs(world:queryOverlap(probe)) do
		local entity = collider.entity
		if entity ~= excludeEntity then
			if not entity then
				return true
			elseif entity.isPushable and horizontalOverlap(probe, entity.collider:getBounds()) > OVERLAP_TOLERANCE then
				return true
			end
		end
	end

	return false
end

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

-- Clears this teleporter's own tile before it may activate (DECISIONS.md
-- Q2b: the source gets the full push-to-clear treatment). Returns true if
-- the tile is clear -- already, or after pushing the one overlapping box out
-- of the way -- false if it's stuck and the teleporter must not activate at
-- all (DECISIONS.md Q3: no chain push).
function Teleport:clearOwnTile(user)
	local bounds = groundTileBounds(self.collider:getBounds())
	local pushables = overlappingPushables(bounds)

	if #pushables == 0 then
		return true
	end

	local box = pushables[1].entity
	local escapeBlocked = {
		left = escapeCellBlocked(bounds, 'left', box),
		right = escapeCellBlocked(bounds, 'right', box),
	}
	local result = PushableSupport.sourceTileClearCheck(bounds, pushables, escapeBlocked)

	if result.status == 'stuck' then
		return false
	end

	box.pushable:pushOneTile(result.direction, user.speed)
	return true
end

-- Whether the resolved destination teleporter's tile is clear -- a plain
-- occupied check, nothing pushed (DECISIONS.md Q2b: there's no player there
-- to push anything out of the way).
function Teleport:destinationTileClear()
	local targetEntity = self.target.entity
	if not targetEntity then
		return true
	end

	local bounds = groundTileBounds(targetEntity.collider:getBounds())
	local pushables = overlappingPushables(bounds)
	return not PushableSupport.destinationTileOccupied(pushables)
end


function Teleport:use(user)
	if self.target and self:clearOwnTile(user) and self:destinationTileClear() then
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
