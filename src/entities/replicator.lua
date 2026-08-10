-- A ceiling-mounted replicator that periodically spawns an entity archetype
-- from its own map position (a push_box by default) which then falls under
-- gravity into the room. `interval` (seconds) controls cadence, `spawnType`
-- names the archetype (must resolve via entity_factory's searchPaths, default
-- 'push_box'), optional `maxTotal` caps how many are ever spawned, and a
-- `Switchable` (linked switch) starts/stops spawning. Spawns reuse the proven
-- runtime path from src/entities/cage.lua -- self.map:loadEntity(spawnType,
-- layer, mockObject) -- the same path GameAPI.spawnEntity drives. The mock
-- object carries NO gid so PushableSupport.spawnCentre treats it top-anchored
-- and the box centre lands exactly under the replicator; the spawned
-- collider self-registers in the bump world via Collider:init ->
-- world:newCollider. See NOTES.md for the decided contract.

local Replicator = Class{__includes = Entity}

local DEFAULT_INTERVAL = 3.0
local DEFAULT_SPAWN_TYPE = 'push_box'

-- How many spawns are due after `elapsed` seconds at `interval` cadence.
-- Pure floor-division: at 3s/interval a 6.4s accumulated update fires 2.
-- Interval is clamped above zero so a degenerate authored interval can never
-- spin into an infinite loop on one long frame.
local function dueSpawns(elapsed, interval)
	interval = math.max(interval or 0, 0.0001)
	elapsed = math.max(elapsed or 0, 0)
	return math.floor(elapsed / interval)
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
	self.interval = tonumber(object.properties.interval) or DEFAULT_INTERVAL
	self.spawnType = object.properties.spawnType or DEFAULT_SPAWN_TYPE
	-- maxTotal is optional: nil = spawn forever; tunnable cap for gated rooms
	local maxTotal = tonumber(object.properties.maxTotal)
	self.maxTotal = maxTotal and math.max(maxTotal, 0) or nil
	self.enabled = true
	if object.properties.enabled ~= nil and object.properties.enabled ~= true then
		self.enabled = false
	end

	self.map = map
	self.spawnLayer = object.layer
	self.elapsed = 0
	self.spawned = 0

	-- no collider of its own: a ceiling machine, only the spawned boxes collide
	self:addComponent(Switchable{
		entity = self,
		onStateChange = function(enabled)
			-- stop in place / resume: freezing the accumulator while disabled
			-- means re-enabling resumes at the same cadence phase
			self.enabled = enabled
		end
	})
end

-- Accumulate time and fire every `interval` seconds while enabled. The
-- elapsed is reduced by `due * interval` (not reset to 0) so cadence keeps no
-- drift over long frames, and the due count is capped by maxTotal when set.
-- When switched off the accumulator simply stops; re-enabling resumes from
-- the saved phase.
function Replicator:update(dt)
	Entity.update(self, dt)

	if not self.enabled then
		return
	end
	if not self.map or not self.spawnLayer then
		return
	end

	self.elapsed = self.elapsed + dt
	local due = dueSpawns(self.elapsed, self.interval)
	if due == 0 then
		return
	end

	if self.maxTotal then
		due = math.min(due, math.max(self.maxTotal - self.spawned, 0))
	end

	for _ = 1, due do
		if self.maxTotal and self.spawned >= self.maxTotal then
			break
		end
		self:spawn()
	end
	self.elapsed = self.elapsed - due * math.max(self.interval, 0.0001)
end

-- Build a top-anchored mock object at the replicator's own position and hand
-- it to the map's loadEntity, which constructs the archetype and appends it
-- to this object layer's entity list -- so it updates/draws/falls immediately.
-- The box top-left is offset by a full height because the replicator is a
-- bottom-anchored tile object: the spawned box centre lands exactly where the
-- machine sits.
function Replicator:spawn()
	self.spawned = self.spawned + 1
	local object = self.object
	local mockObject = {
		type = self.spawnType,
		name = self.spawnType,
		x = object.x,
		y = object.y - object.height,
		width = object.width,
		height = object.height,
		properties = {},
		layer = self.spawnLayer,
	}
	return self.map:loadEntity(self.spawnType, self.spawnLayer, mockObject)
end

-- White-box seam for tests/unit/ only: pure cadence math and defaults.
-- Not for production use.
Replicator._internal = {
	DEFAULT_INTERVAL = DEFAULT_INTERVAL,
	DEFAULT_SPAWN_TYPE = DEFAULT_SPAWN_TYPE,
	dueSpawns = dueSpawns,
}

return Replicator