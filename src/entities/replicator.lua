-- A ceiling- or floor-mounted replicator that, on EVERY press of a linked
-- toggle Switch, emits a pushable box (default) once. No timer, no interval
-- cadence -- the switch's on/off state is irrelevant, only the press pulse
-- matters. `spawnType` names the archetype (must resolve via
-- entity_factory's searchPaths, default 'push_box'), `maxSpawns` caps how
-- many are ever spawned (default 1, no refunds; nil = unlimited), and the
-- emit point is derived from the Tiled `rotation` (0 = ceiling mount, one
-- tile below the surface; 180 = floor mount, two tiles above the top face)
-- unless an optional object `polyline` overrides the exact spawn point.
-- Spawns reuse the proven runtime path from src/entities/cage.lua --
-- self.map:loadEntity(spawnType, layer, mockObject) -- the same path
-- GameAPI.spawnEntity drives. The mock object carries NO gid so
-- PushableSupport.spawnCentre treats it top-anchored and the box centre
-- lands exactly at the emit point; the spawned collider self-registers in
-- the bump world via Collider:init -> world:newCollider. See NOTES.md for
-- the decided contract.

local Replicator = Class{__includes = Entity}

local DEFAULT_SPAWN_TYPE = 'push_box'
local DEFAULT_MAX_SPAWNS = 1

-- Where a spawned box's TOP edge is emitted, given the replicator's authored
-- object. The replicator is a bottom-anchored tile object (object.y is the
-- bottom edge) unless a polyline overrides the exact spawn point.
--
--   rotation 0  (ceiling mount): the machine's underside sits at object.y,
--                the box top edge drops one tile below it
--   rotation 180 (floor mount):  the machine's top face sits at
--                object.y - object.height, the box top edge starts two tiles
--                up (one tile of machine + one tile of gap)
--   polyline:    the first point IS the spawn point, taken verbatim --
--                polyline points are already absolute once the map resolved
--                them (STM re-anchors, same contract as mover_platform and
--                jump_pad) so the object origin must NOT be added again
--   unknown rotation: treated as a ceiling mount
local function emitY(object)
	if object.polyline and object.polyline[1] then
		return object.polyline[1].y
	end

	local rotation = tonumber(object.rotation) or 0
	if rotation == 180 then
		return object.y - 2 * object.height
	end

	return object.y + object.height
end

function Replicator:init(object, map)
	Entity.init(self, object, 'replicator')

	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)

	self.sprite = self:addComponent(Sprite{
		image = 'res/img/default.png',
		frames = 1,
		duration = 1.0,
		loop = false,
		position = position,
		shape_arguments = shape_arguments,
	})

	-- props with the defaults settled in NOTES.md
	self.spawnType = object.properties.spawnType or DEFAULT_SPAWN_TYPE
	-- maxSpawns is the whole-spawn budget: absent defaults to 1, present
	-- clamps to >= 0, nil means unlimited (spawn on every press forever)
	local maxSpawns = tonumber(object.properties.maxSpawns)
	if maxSpawns == nil then
		self.maxSpawns = DEFAULT_MAX_SPAWNS
	else
		self.maxSpawns = math.max(maxSpawns, 0)
	end

	self.map = map
	self.spawnLayer = object.layer
	self.spawned = 0

	-- no collider of its own: a ceiling/floor machine, only the spawned boxes
	-- collide. onStateChange fires on EVERY switch press; the switch's on/off
	-- state is irrelevant (the `enabled` argument is ignored) -- the handler
	-- spawns once so long as budget remains.
	self:addComponent(Switchable{
		entity = self,
		onStateChange = function(enabled, switch, user)
			if self.maxSpawns == nil or self.spawned < self.maxSpawns then
				self:spawn()
			end
		end
	})
end

-- Build a top-anchored mock object at the emit point and hand it to the
-- map's loadEntity, which constructs the archetype and appends it to this
-- object layer's entity list -- so it updates/draws/falls immediately as a
-- normal physics body.
function Replicator:spawn()
	self.spawned = self.spawned + 1
	local object = self.object
	local override = object.polyline and object.polyline[1]
	local mockObject = {
		type = self.spawnType,
		name = self.spawnType,
		x = override and override.x or object.x,
		y = emitY(object),
		width = object.width,
		height = object.height,
		properties = {},
		layer = self.spawnLayer,
	}
	return self.map:loadEntity(self.spawnType, self.spawnLayer, mockObject)
end

-- White-box seam for tests/unit/ only: pure emit-point math and defaults.
-- Not for production use.
Replicator._internal = {
	DEFAULT_SPAWN_TYPE = DEFAULT_SPAWN_TYPE,
	DEFAULT_MAX_SPAWNS = DEFAULT_MAX_SPAWNS,
	emitY = emitY,
}

return Replicator