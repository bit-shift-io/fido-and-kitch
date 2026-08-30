-- Shared bake-a-parsed-map logic for jump-pad trajectories: pure data
-- transformation over a raw Tiled .tmj map table (the plain JSON shape from
-- src/utils/json, NOT the game's templated object parser -- see
-- tools/jump_pad_trajectory/main.lua's header for why).
--
-- For every jump_pad object that has a `target` property and no `path`
-- property, computes a parabolic arc from the pad to its target
-- (src/utils/jump_pad_trajectory), appends a new polyline object encoding
-- that arc, and sets the pad's `path` property to the new object's id.
-- A pad that already has a `path` is left untouched (re-baking requires
-- removing it first); a pad with neither `target` nor `path` is left
-- untouched too (nothing to derive a path from).
--
-- Pure: no love.*, no io, no debug-flag concerns -- this same module backs
-- both the offline CLI (tools/jump_pad_trajectory/main.lua) and a later
-- in-game debug bake, so it must stay usable from plain `lua` and from
-- inside the running game alike.
local Trajectory = require('src.utils.jump_pad_trajectory')

local Bake = {}

local function findProperty(object, name)
	for _, prop in ipairs(object.properties or {}) do
		if prop.name == name then
			return prop
		end
	end
	return nil
end

-- Recursively collects every object across all objectgroup layers,
-- descending into 'group' layers -- Tiled allows nesting objectgroups
-- inside a group layer, so a simple top-level scan isn't safe.
local function collectObjects(layers, out)
	out = out or {}
	for _, layer in ipairs(layers or {}) do
		if layer.type == 'objectgroup' then
			for _, object in ipairs(layer.objects or {}) do
				table.insert(out, object)
			end
		elseif layer.type == 'group' then
			collectObjects(layer.layers, out)
		end
	end
	return out
end

local function findObjectById(objects, id)
	for _, object in ipairs(objects) do
		if object.id == id then
			return object
		end
	end
	return nil
end

-- A raw Tiled object's x/y is its bottom-left corner (gid/tile-object
-- convention), not its visual centre -- matches Rect.centreOfMapObject
-- (src/utils/rect.lua), which is what JumpPad:init actually positions the
-- pad's collider at. Using raw x/y directly as the arc's launch origin
-- would offset the baked arc by half the pad's width/height from where the
-- player actually launches. Safe to apply to point objects too (width and
-- height are 0, so the formula is a no-op for them).
local function centreOfObject(object)
	return {
		x = object.x + (object.width or 0) * 0.5,
		y = object.y - (object.height or 0) * 0.5,
	}
end

-- First top-level 'waypoints' objectgroup layer, matching the convention
-- already used by hand-authored maps (tests/fixtures/jump_pad_room.tmj).
local function findWaypointsLayer(map)
	for _, layer in ipairs(map.layers or {}) do
		if layer.type == 'objectgroup' and layer.name == 'waypoints' then
			return layer
		end
	end
	return nil
end

-- Creates a top-level 'waypoints' objectgroup layer if the map has none
-- yet, using a fresh layer id derived the same way object ids are (scan
-- existing layer ids, don't assume nextlayerid alone is trustworthy).
local function ensureWaypointsLayer(map)
	local layer = findWaypointsLayer(map)
	if layer then return layer end

	local nextLayerId = map.nextlayerid or 1
	for _, l in ipairs(map.layers or {}) do
		if l.id and l.id >= nextLayerId then
			nextLayerId = l.id + 1
		end
	end

	layer = {
		id = nextLayerId,
		type = 'objectgroup',
		name = 'waypoints',
		draworder = 'topdown',
		visible = true,
		opacity = 1,
		class = '',
		offsetx = 0,
		offsety = 0,
		parallaxx = 1,
		parallaxy = 1,
		properties = {},
		objects = {},
	}
	table.insert(map.layers, layer)
	map.nextlayerid = nextLayerId + 1
	return layer
end

-- A fresh unique object id: scan every object across all layers (nested
-- groups included), don't assume map.nextobjectid alone is trustworthy.
local function nextObjectId(map, allObjects)
	local nextId = map.nextobjectid or 1
	for _, object in ipairs(allObjects) do
		if object.id and object.id >= nextId then
			nextId = object.id + 1
		end
	end
	return nextId
end

--- Every jump_pad object found anywhere in the map (any nesting depth).
function Bake.findJumpPads(map)
	local pads = {}
	for _, object in ipairs(collectObjects(map.layers)) do
		if object.type == 'jump_pad' then
			table.insert(pads, object)
		end
	end
	return pads
end

--- Bakes every eligible jump_pad in `map`, mutating it in place. Returns
-- the number of pads baked. `filename` is optional and used only to make
-- a missing-target error actionable (naming the file and the object id).
function Bake.bakeMap(map, filename)
	filename = filename or '<map>'
	local allObjects = collectObjects(map.layers)
	local baked = 0

	for _, pad in ipairs(allObjects) do
		if pad.type == 'jump_pad' then
			local pathProp = findProperty(pad, 'path')
			local targetProp = findProperty(pad, 'target')

			if not pathProp and targetProp then
				local targetId = targetProp.value
				local targetObject = findObjectById(allObjects, targetId)
				if not targetObject then
					error(string.format(
						'jump_pad_trajectory bake: %s: jump_pad object id=%s references missing target object id=%s',
						filename, tostring(pad.id), tostring(targetId)
					), 0)
				end

				local arc = Trajectory.computeArc(
					centreOfObject(pad),
					centreOfObject(targetObject)
				)

				-- Polyline points are stored relative to the object's own
				-- x/y on disk (Tiled convention) -- the object's x/y is
				-- the arc's first point (world-space launch origin), and
				-- every stored point is offset from it, so the first
				-- stored point is always {x=0, y=0}.
				local origin = arc[1]
				local polyline = {}
				for _, point in ipairs(arc) do
					table.insert(polyline, {x = point.x - origin.x, y = point.y - origin.y})
				end

				local waypointsLayer = ensureWaypointsLayer(map)
				local newId = nextObjectId(map, allObjects)

				local pathObject = {
					id = newId,
					name = 'jump_pad_path',
					type = '',
					x = origin.x,
					y = origin.y,
					width = 0,
					height = 0,
					visible = true,
					rotation = 0,
					properties = {},
					polyline = polyline,
				}
				table.insert(waypointsLayer.objects, pathObject)
				table.insert(allObjects, pathObject)

				pad.properties = pad.properties or {}
				table.insert(pad.properties, {type = 'object', name = 'path', value = newId})

				map.nextobjectid = newId + 1
				baked = baked + 1
			end
		end
	end

	return baked
end

return Bake
