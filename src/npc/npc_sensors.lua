-- src/npc/npc_sensors.lua
-- Spatial probes and per-frame sensory checks for NPCBase (kill zones, target
-- detection, friendly despawn), plus the ground/wall probe helpers those and
-- the NPC states rely on. Extracted from src/npc/npc_base.lua so the probe
-- constants live with the bounds math that uses them.
local Sensors = {}

-- Spatial probe constants (world px) used by the collision queries.
local KILL_ZONE_INSET = 2 -- shrink the hitbox when probing kill zones
local GROUND_PROBE = { min = 1, max = 3 } -- probe band just below the feet
local WALL_PROBE_DIST = 8 -- how far ahead a wall check reaches
local WALL_PROBE_INSET = 2 -- vertical inset of the wall probe
local GROUND_AHEAD_PROBE_DIST = 16 -- how far ahead a ground check reaches
local GROUND_AHEAD_VERT_RANGE = 8 -- vertical range of the ground probe

-- Shared "is anything solid in these bounds" scan used by the ground/wall
-- probes below. With requireSolid=true only terrain (no owning entity) and
-- solid entities count; with requireSolid=false any non-sensor collider does.
local function querySolidIn(world, collider, bounds, requireSolid)
	local items = world:queryOverlap(bounds)
	for _, item in ipairs(items) do
		if item ~= collider and not item.sensor then
			if not requireSolid or not item.entity or item.solid then
				return true
			end
		end
	end
	return false
end

function Sensors.isOnGround(npc)
	if npc.collider then
		local w = npc.collider.world or world
		if not w then
			return false
		end
		local bounds = {
			left = npc.collider.x,
			right = npc.collider.x + npc.collider.width,
			top = npc.collider.y + npc.collider.height + GROUND_PROBE.min,
			bottom = npc.collider.y + npc.collider.height + GROUND_PROBE.max,
		}
		return querySolidIn(w, npc.collider, bounds, false)
	end
	return false
end

function Sensors.isWallAhead(npc, direction)
	if not npc.collider then
		return false
	end
	local w = npc.collider.world or world
	if not w then
		return false
	end
	local bounds = npc.collider:getBounds()
	if direction == "right" then
		bounds.left = bounds.right
		bounds.right = bounds.right + WALL_PROBE_DIST
	else
		bounds.right = bounds.left
		bounds.left = bounds.left - WALL_PROBE_DIST
	end
	bounds.top = bounds.top + WALL_PROBE_INSET
	bounds.bottom = bounds.bottom - WALL_PROBE_INSET
	return querySolidIn(w, npc.collider, bounds, true)
end

function Sensors.isGroundAhead(npc, direction)
	if not npc.collider then
		return false
	end
	local w = npc.collider.world or world
	if not w then
		return false
	end
	local bounds = npc.collider:getBounds()
	if direction == "right" then
		bounds.left = bounds.right
		bounds.right = bounds.right + GROUND_AHEAD_PROBE_DIST
	else
		bounds.right = bounds.left
		bounds.left = bounds.left - GROUND_AHEAD_PROBE_DIST
	end
	bounds.top = bounds.bottom - GROUND_AHEAD_VERT_RANGE
	bounds.bottom = bounds.bottom + GROUND_AHEAD_VERT_RANGE
	return querySolidIn(w, npc.collider, bounds, true)
end

-- Kill-zone overlap check: probe the world just inside the collider bounds
-- and die immediately if any kill zone is found.
function Sensors.checkKillZones(npc)
	if not world then
		return false
	end
	local bounds = npc.collider:getBounds()
	bounds.left = bounds.left + KILL_ZONE_INSET
	bounds.right = bounds.right - KILL_ZONE_INSET
	bounds.top = bounds.top + KILL_ZONE_INSET
	bounds.bottom = bounds.bottom - KILL_ZONE_INSET

	local cols = world:queryBounds(bounds)
	for _, other in ipairs(cols) do
		if other.entity and other.entity.isKillZone then
			npc:die(other.entity.deathType)
			return true
		end
	end
	return false
end

-- Scan all players and set the NPC's target to the closest one within
-- detection radius.
function Sensors.detectNearestPlayer(npc)
	if not players or #players == 0 then
		return
	end
	local closest, closestDist = nil, npc.config.detectionRadius
	for _, player in ipairs(players) do
		if player and not player.dead and player.collider then
			local px = player.collider:getX()
			local py = player.collider:getY()
			local dx, dy = px - npc.x, py - npc.y
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist < closestDist then
				closestDist = dist
				closest = { x = px, y = py }
			end
		end
	end
	npc:setTarget(closest)
end

-- Despawn a friendly NPC that has wandered beyond its configured radius
-- from the current target. This is a catch-up rescue for a ground NPC that
-- got physically stuck behind terrain -- it never applies to a flying NPC
-- (canFly), which ignores terrain collision entirely and can always close
-- the gap on its own, visibly, via FollowState's normal acceleration. Note
-- despawnDistance stays > 0 for flying NPCs regardless (ExitDoor's
-- despawnNearbyNPCs uses it as a "this is a friendly companion" marker,
-- unrelated to this rescue mechanism).
function Sensors.checkDespawn(npc)
	if npc.config.canFly or npc.config.despawnDistance <= 0 or not npc.target or npc:isDead() then
		return
	end
	local tx, ty = npc:getTargetPos()
	if not tx then
		return
	end
	local dx, dy = tx - npc.x, ty - npc.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist > npc.config.despawnDistance then
		npc:despawnToTarget()
	end
end

return Sensors
