local DebugOverlay = {}
DebugOverlay.__index = DebugOverlay

local lg = love.graphics

function DebugOverlay:new()
	return setmetatable({
		enabled = false,
		showHitboxes = true,
		showLadders = true,
		showKillZones = true,
		showSafePositions = true,
		showCameraBounds = true,
		showPaths = true,
	}, DebugOverlay)
end

function DebugOverlay:toggle()
	self.enabled = not self.enabled
end

function DebugOverlay:draw(world, map, players, viewRect, cameraFramingBounds)
	if not self.enabled or not conf.drawphysics then return end

	lg.push()
	lg.origin()

	local tx, ty, sx, sy = viewRect.tx or 0, viewRect.ty or 0, viewRect.sx or 1, viewRect.sy or 1

	lg.translate(math.floor(tx), math.floor(ty))
	lg.scale(sx, sy)
	lg.setLineWidth(2 / math.max(sx, sy))  -- keep line width consistent in world space

	-- Draw world colliders (physics bodies)
	if self.showHitboxes and world and world.colliders then
		lg.setColor(1, 1, 1, 0.5)
		for collider, _ in pairs(world.colliders) do
			if collider.getBounds then
				local b = collider:getBounds()
				lg.rectangle('line', b.left, b.top, b.width, b.height)
				
				-- Show sensor vs solid
				if collider.sensor then
					lg.setColor(1, 0.5, 0, 0.8)
					lg.rectangle('line', b.left, b.top, b.width, b.height)
				end
				lg.setColor(1, 1, 1, 0.5)
			end
		end
	end

	-- Draw query rectangles (player sensor zones - ladder, ground, killzone checks)
	if self.showHitboxes and world and world.queryRects then
		lg.setColor(1, 0, 0, 0.8)
		for _, q in ipairs(world.queryRects) do
			lg.rectangle('line', q.x, q.y, q.width, q.height)
		end
		-- Clear after drawing so they don't accumulate across frames
		world.queryRects = {}
	end

	-- Draw ladder sensors
	if self.showLadders and world and world.colliders then
		lg.setColor(0, 1, 1, 1)
		for collider, _ in pairs(world.colliders) do
			if collider.sensor and collider.entity and collider.entity.isLadder then
				local b = collider:getBounds()
				lg.rectangle('line', b.left, b.top, b.width, b.height)
			end
		end
	end

	-- Draw kill zones
	if self.showKillZones and world and world.colliders then
		lg.setColor(1, 0, 1, 1)
		for collider, _ in pairs(world.colliders) do
			if collider.entity and collider.entity.isKillZone then
				local b = collider:getBounds()
				lg.rectangle('line', b.left, b.top, b.width, b.height)
			end
		end
	end

	-- Draw player safe positions
	if self.showSafePositions and players then
		lg.setColor(0, 1, 0, 1)
		for _, player in ipairs(players) do
			if player.safePosition then
				local size = 8
				lg.line(player.safePosition.x - size, player.safePosition.y, player.safePosition.x + size, player.safePosition.y)
				lg.line(player.safePosition.x, player.safePosition.y - size, player.safePosition.x, player.safePosition.y + size)
			end
		end
	end

	-- Draw camera framing bounds
	if self.showCameraBounds and cameraFramingBounds then
		lg.setColor(1, 1, 0, 0.8)
		lg.rectangle('line', cameraFramingBounds.x, cameraFramingBounds.y, cameraFramingBounds.w, cameraFramingBounds.h)
	end

	-- Draw NPC paths
	if self.showPaths and map and map.layers then
		lg.setColor(1, 0.5, 0, 0.6)
		for _, layer in ipairs(map.layers) do
			if layer.entities then
				for _, entity in ipairs(layer.entities) do
					if entity.path and entity.path.points then
						local pts = entity.path.points
						for i = 1, #pts - 1 do
							lg.line(pts[i].x, pts[i].y, pts[i+1].x, pts[i+1].y)
						end
					end
				end
			end
		end
	end

	lg.pop()
	lg.setColor(1, 1, 1, 1)
end

return DebugOverlay