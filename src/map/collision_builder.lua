local CollisionBuilder = {}
CollisionBuilder.__index = CollisionBuilder

local function getColliderFromShape(obj)
	if obj.shape == "rectangle" then
		local rect = obj.rectangle
		local x = rect[1].x
		local y = rect[1].y
		local width = rect[3].x - x
		local height = rect[3].y - y
		local center_x = x + width * 0.5
		local center_y = y + height * 0.5
		return Collider({
			shape_type = "rectangle",
			shape_arguments = { width, height },
			body_type = "static",
			position = Vector(center_x, center_y),
		})
	end
end

local function createStaticPhysicsBodies(layer)
	local colliders = {}

	if layer.type == "objectgroup" and layer.objects then
		for i, obj in pairs(layer.objects) do
			local col = getColliderFromShape(obj)
			if col then
				col:setType("static")
				table.insert(colliders, col)
			end
		end
	end

	if layer.type == "tilelayer" and layer.data then
		for y, row in pairs(layer.data) do
			for x, cell in pairs(row) do
				local tileset = layer.map.tilesets[cell.tileset]
				local width = cell.width
				local height = cell.height
				local margin = tileset.margin
				local spacing = tileset.spacing
				local offset_x = cell.offset.x + width * 0.5
				local offset_y = cell.offset.y + height * 0.5
				local quadX = ((x - 1) * width + margin + (x - 1) * spacing) + offset_x
				local quadY = ((y - 1) * height + margin + (y - 1) * spacing) + offset_y

				local col = Collider({
					shape_type = "rectangle",
					shape_arguments = { width, height },
					body_type = "static",
					position = Vector(quadX, quadY),
				})
				table.insert(colliders, col)
			end
		end
	end

	return colliders
end

local function createStaticPhysicsBodyBoundary(map)
	local width = map.width * map.tilewidth
	local height = map.height * map.tileheight

	local depth = 10
	local boundaryLeft = Collider({
		shape_type = "rectangle",
		shape_arguments = { depth, height + (2 * depth) },
		body_type = "static",
		position = Vector(-depth * 0.5, height * 0.5),
	})
	local boundaryTop = Collider({
		shape_type = "rectangle",
		shape_arguments = { width + (2 * depth), depth },
		body_type = "static",
		position = Vector(width * 0.5, -depth * 0.5),
	})
	local boundaryRight = Collider({
		shape_type = "rectangle",
		shape_arguments = { depth, height + (2 * depth) },
		body_type = "static",
		position = Vector(width + (depth * 0.5), height * 0.5),
	})
	local boundaryBottom = Collider({
		shape_type = "rectangle",
		shape_arguments = { width + (2 * depth), depth },
		body_type = "static",
		position = Vector(width * 0.5, height + (depth * 0.5)),
	})

	return { boundaryLeft, boundaryTop, boundaryRight, boundaryBottom }
end

function CollisionBuilder:new()
	return setmetatable({}, CollisionBuilder)
end

function CollisionBuilder:createStaticPhysicsBodies(layer)
	return createStaticPhysicsBodies(layer)
end

function CollisionBuilder:createStaticPhysicsBodyBoundary(map)
	return createStaticPhysicsBodyBoundary(map)
end

return CollisionBuilder
