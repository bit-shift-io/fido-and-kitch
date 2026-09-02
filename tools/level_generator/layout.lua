-- Turns zones into a concrete grid: a full-width ground row at the bottom,
-- then a chain of smaller platforms stepping upward, each connected to the
-- previous one by exactly one ladder (never a bare gap -- MovementModel has
-- no notion of a jump). Guarantees full reachability by construction: every
-- new platform is placed so it straddles the ladder column chosen from the
-- previous zone's x-range.
local Layout = {}

local SIZE_PRESETS = {
	small = { width = 24, height = 16, zoneCount = 3 },
	medium = { width = 40, height = 25, zoneCount = 5 },
	large = { width = 56, height = 36, zoneCount = 7 },
}

local MIN_VERTICAL_MARGIN = 2 -- rows always left clear above the topmost zone

local function clampPlatformToWidth(x1, x2, width)
	if x2 > width then
		local platformWidth = x2 - x1 + 1
		x2 = width
		x1 = x2 - platformWidth + 1
	end
	if x1 < 1 then
		local platformWidth = x2 - x1 + 1
		x1 = 1
		x2 = x1 + platformWidth - 1
	end
	return x1, x2
end

--- @param rng A tools.level_generator.rng instance.
-- @param opts { size = 'small'|'medium'|'large' }
-- @return { width, height, zones = {{x1,x2,y}, ...}, ladders = {{x,yTop,yBottom}, ...} }
function Layout.generate(rng, opts)
	opts = opts or {}
	local preset = SIZE_PRESETS[opts.size or "medium"]

	local width, height, zoneCount = preset.width, preset.height, preset.zoneCount

	local zones = { { x1 = 1, x2 = width, y = height } }
	local ladders = {}

	local prev = zones[1]
	for _ = 2, zoneCount do
		local remainingHeight = prev.y - MIN_VERTICAL_MARGIN
		if remainingHeight < 3 then
			break
		end

		local stepUp = rng:nextInt(2, math.min(4, remainingHeight))
		local newY = prev.y - stepUp

		local maxPlatformWidth = math.min(8, width - 2)
		local minPlatformWidth = math.min(3, maxPlatformWidth)
		local platformWidth = rng:nextInt(minPlatformWidth, maxPlatformWidth)

		local ladderX = rng:nextInt(prev.x1, prev.x2)

		local leftSlack = math.min(platformWidth - 1, ladderX - 1)
		local x1 = ladderX - rng:nextInt(0, leftSlack)
		local x2 = x1 + platformWidth - 1
		x1, x2 = clampPlatformToWidth(x1, x2, width)

		-- The width clamp can only ever shrink the margin on one side, and
		-- only when ladderX was already within platformWidth-1 of that edge
		-- -- so ladderX (which sits inside [x1 - leftSlack .. x1 + slack's
		-- complement], i.e. always within platformWidth of its original x1)
		-- remains inside [x1, x2] after clamping. Assert it defensively so a
		-- future edit to the clamp math fails loudly instead of emitting an
		-- unreachable zone.
		if ladderX < x1 or ladderX > x2 then
			error("Layout: ladder column drifted outside its platform after clamping")
		end

		local zone = { x1 = x1, x2 = x2, y = newY }
		table.insert(zones, zone)
		table.insert(ladders, { x = ladderX, yTop = newY, yBottom = prev.y })

		prev = zone
	end

	return { width = width, height = height, zones = zones, ladders = ladders }
end

return Layout
