local Trajectory = require('src.utils.jump_pad_trajectory')

-- Helper: check if a point is a table with x and y
local function isValidPoint(p)
	return type(p) == 'table' and type(p.x) == 'number' and type(p.y) == 'number'
end

-- Helper: find the apex (point with extreme y) in the arc
local function findApex(points)
	local maxDistance = -math.huge
	local apexIdx = 1

	-- Find the point with the most extreme y value (could be max or min)
	for i, p in ipairs(points) do
		-- Distance from the line connecting first and last points
		local p1 = points[1]
		local p2 = points[#points]

		-- Line from p1 to p2
		local dx = p2.x - p1.x
		local dy = p2.y - p1.y
		local len = math.sqrt(dx * dx + dy * dy)

		if len > 0.001 then
			-- Distance from p to the line
			local dist = math.abs((dy) * (p.x - p1.x) - (dx) * (p.y - p1.y)) / len
			if dist > maxDistance then
				maxDistance = dist
				apexIdx = i
			end
		end
	end

	return points[apexIdx], apexIdx
end

-- Helper: compute arc height (distance from straight line to apex)
local function computeArcHeight(startPoint, targetPoint, apexPoint)
	-- Straight line from start to end at x = apex.x
	local dx = targetPoint.x - startPoint.x
	local dy = targetPoint.y - startPoint.y
	local t = (apexPoint.x - startPoint.x) / dx

	if math.abs(dx) < 0.001 then
		return 0
	end

	local lineYAtApex = startPoint.y + t * dy
	local height = math.abs(lineYAtApex - apexPoint.y)

	return height
end

test('arc starts at startPoint', function()
	local start = {x = 0, y = 0}
	local target = {x = 100, y = 0}

	local arc = Trajectory.computeArc(start, target)

	assertTrue(isValidPoint(arc[1]), 'first point should be valid')
	assertNear(0, arc[1].x, 0.001, 'first x should be 0')
	assertNear(0, arc[1].y, 0.001, 'first y should be 0')
end)

test('arc ends at targetPoint', function()
	local start = {x = 0, y = 0}
	local target = {x = 100, y = 0}

	local arc = Trajectory.computeArc(start, target)

	assertTrue(isValidPoint(arc[#arc]), 'last point should be valid')
	assertNear(100, arc[#arc].x, 0.001, 'last x should be 100')
	assertNear(0, arc[#arc].y, 0.001, 'last y should be 0')
end)

test('arc is a list of {x, y} points', function()
	local start = {x = 10, y = 20}
	local target = {x = 110, y = 20}

	local arc = Trajectory.computeArc(start, target)

	assertTrue(#arc > 0, 'should have at least one point')
	for i, p in ipairs(arc) do
		assertTrue(isValidPoint(p), 'point ' .. i .. ' should be valid {x, y}')
	end
end)

test('longer horizontal distance produces taller apex', function()
	local start = {x = 0, y = 0}
	local factor = 0.15

	-- Distances large enough that the distance-proportional term (factor *
	-- dx) exceeds the minimum-clearance floor (2 tiles = 64px by default),
	-- so the floor doesn't mask the scaling this test is checking.
	local target1 = {x = 1000, y = 0} -- proportional height 150
	local arc1 = Trajectory.computeArc(start, target1, factor)
	local apex1 = findApex(arc1)
	local height1 = computeArcHeight(start, target1, apex1)

	-- Long distance (4x longer)
	local target2 = {x = 4000, y = 0} -- proportional height 600
	local arc2 = Trajectory.computeArc(start, target2, factor)
	local apex2 = findApex(arc2)
	local height2 = computeArcHeight(start, target2, apex2)

	-- Height should be approximately proportional to distance
	-- 4000/1000 = 4, so height2 should be ~4x height1
	local ratio = height2 / height1
	assertTrue(ratio > 3.5 and ratio < 4.5, 'height ratio should be ~4, got ' .. ratio)
end)

test('target above start produces an arc that reaches up', function()
	local start = {x = 0, y = 0}
	local target = {x = 100, y = 50}

	local arc = Trajectory.computeArc(start, target)
	local apex = findApex(arc)

	-- Apex y should be above (i.e. numerically LESS than, since this
	-- engine's y grows downward) the line connecting start to target.
	-- At t=0.5, y = 25 - arcHeight, so apex.y < 25
	assertTrue(apex.y < (start.y + target.y) / 2, 'apex should be elevated above the start-target line')
end)

test('target below start produces a valid arc', function()
	local start = {x = 0, y = 0}
	local target = {x = 100, y = -50}

	local arc = Trajectory.computeArc(start, target)

	assertTrue(#arc > 0, 'should produce an arc')
	assertNear(start.x, arc[1].x, 0.001, 'should start at start.x')
	assertNear(start.y, arc[1].y, 0.001, 'should start at start.y')
	assertNear(target.x, arc[#arc].x, 0.001, 'should end at target.x')
	assertNear(target.y, arc[#arc].y, 0.001, 'should end at target.y')
end)

test('target level with start produces symmetric arc', function()
	local start = {x = 0, y = 100}
	local target = {x = 200, y = 100}

	local arc = Trajectory.computeArc(start, target)
	local apex = findApex(arc)

	-- Apex should be at x = 100 (midpoint)
	assertNear(100, apex.x, 5, 'apex x should be at horizontal midpoint')

	-- Apex should be above the line (numerically less y, since arcHeight is
	-- subtracted and this engine's y grows downward)
	assertTrue(apex.y < start.y, 'apex should be above the start-end line')
end)

test('vertical line (same x) produces a degenerate arc', function()
	local start = {x = 50, y = 0}
	local target = {x = 50.0001, y = 100}

	local arc = Trajectory.computeArc(start, target)

	assertTrue(#arc >= 2, 'should produce at least 2 points')
	assertNear(start.x, arc[1].x, 0.01)
	assertNear(start.y, arc[1].y, 0.01)
	assertNear(target.x, arc[#arc].x, 0.01)
	assertNear(target.y, arc[#arc].y, 0.01)
end)

test('arc height factor affects apex height', function()
	local start = {x = 0, y = 0}
	-- Distance large enough that even the smaller factor's proportional
	-- height (0.05 * 2000 = 100) clears the minimum-clearance floor (64px
	-- by default), so the floor doesn't mask the factor's effect.
	local target = {x = 2000, y = 0}

	-- Small factor
	local arc1 = Trajectory.computeArc(start, target, 0.05)
	local apex1 = findApex(arc1)
	local height1 = computeArcHeight(start, target, apex1)

	-- Large factor
	local arc2 = Trajectory.computeArc(start, target, 0.25)
	local apex2 = findApex(arc2)
	local height2 = computeArcHeight(start, target, apex2)

	-- Larger factor should produce taller arc
	assertTrue(height2 > height1, 'larger factor should produce taller arc')
	local ratio = height2 / height1
	assertNear(5, ratio, 0.1, 'ratio should be 0.25/0.05 = 5')
end)

test('negative horizontal distance (target left of start) works', function()
	local start = {x = 100, y = 0}
	local target = {x = 0, y = 0}

	local arc = Trajectory.computeArc(start, target)

	assertTrue(#arc > 0, 'should produce an arc')
	assertNear(start.x, arc[1].x, 0.001, 'should start at start.x')
	assertNear(target.x, arc[#arc].x, 0.001, 'should end at target.x')

	-- Arc should have an apex (raised above the line, i.e. numerically less
	-- y, since this engine's y grows downward)
	local apex = findApex(arc)
	assertTrue(apex.y < start.y, 'apex should be elevated')
end)

test('a close, level jump still clears 2 tiles above both endpoints', function()
	-- A short distance whose distance-proportional height alone (0.15 * 50
	-- = 7.5px) would barely rise at all -- the minimum-clearance floor
	-- should take over instead.
	local start = {x = 0, y = 100}
	local target = {x = 50, y = 100}

	local arc = Trajectory.computeArc(start, target)

	local peakY = math.huge
	for _, p in ipairs(arc) do
		if p.y < peakY then peakY = p.y end
	end

	local highestEndpointY = math.min(start.y, target.y)
	assertTrue(peakY <= highestEndpointY - 64,
		string.format('expected peak y <= %d (2 tiles above the higher endpoint), got %.1f', highestEndpointY - 64, peakY))
end)

test('minimum clearance is measured against the HIGHER of the two endpoints, even when they differ in height', function()
	-- Target sits well above the pad -- the floor must clear 2 tiles above
	-- the target (the higher point), not the pad.
	local start = {x = 0, y = 100}
	local target = {x = 50, y = -200}

	local arc = Trajectory.computeArc(start, target)

	local peakY = math.huge
	for _, p in ipairs(arc) do
		if p.y < peakY then peakY = p.y end
	end

	local highestEndpointY = math.min(start.y, target.y)
	assertTrue(peakY <= highestEndpointY - 64,
		string.format('expected peak y <= %d (2 tiles above the higher endpoint), got %.1f', highestEndpointY - 64, peakY))
end)

test('a custom minClearance overrides the default 2-tile floor', function()
	local start = {x = 0, y = 100}
	local target = {x = 50, y = 100}

	local arc = Trajectory.computeArc(start, target, 0.15, 10)

	local peakY = math.huge
	for _, p in ipairs(arc) do
		if p.y < peakY then peakY = p.y end
	end

	assertTrue(peakY <= 100 - 10, 'peak should clear the custom 10px floor')
	assertTrue(peakY > 100 - 64, 'peak should NOT clear the default 64px floor once overridden smaller')
end)

test('arc points are strictly monotonic in x', function()
	local start = {x = 0, y = 0}
	local target = {x = 100, y = 50}

	local arc = Trajectory.computeArc(start, target)

	if start.x < target.x then
		for i = 2, #arc do
			assertTrue(arc[i].x >= arc[i-1].x, 'x coordinates should be non-decreasing')
		end
	else
		for i = 2, #arc do
			assertTrue(arc[i].x <= arc[i-1].x, 'x coordinates should be non-increasing')
		end
	end
end)
