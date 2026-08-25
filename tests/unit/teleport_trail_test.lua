-- Unit tests for teleport trail curve generation math
local teleport_trail = require('src.fx.teleport_trail')

test('computeCurvePoint returns start position at t=0', function()
    local start = {x = 100, y = 200}
    local dest = {x = 500, y = 200}
    local curve = teleport_trail.generateCurve(start, dest)
    local p = teleport_trail.computeCurvePoint(curve, 0)
    assertNear(100, p.x, 0.001, 'start x at t=0')
    assertNear(200, p.y, 0.001, 'start y at t=0')
end)

test('computeCurvePoint returns dest position at t=1', function()
    local start = {x = 100, y = 200}
    local dest = {x = 500, y = 200}
    local curve = teleport_trail.generateCurve(start, dest)
    local p = teleport_trail.computeCurvePoint(curve, 1)
    assertNear(500, p.x, 0.001, 'dest x at t=1')
    assertNear(200, p.y, 0.001, 'dest y at t=1')
end)

test('computeCurvePoint at t=0.5 has y offset for horizontal travel', function()
    local start = {x = 100, y = 200}
    local dest = {x = 500, y = 200}
    local curve = teleport_trail.generateCurve(start, dest)
    local p = teleport_trail.computeCurvePoint(curve, 0.5)
    assertNear(300, p.x, 1.0, 'midpoint x at t=0.5')
    -- Should have perpendicular sine wave offset
    assertTrue(p.y ~= 200, 'y should be offset from straight line at midpoint')
end)

test('computeCurvePoint at t=0.5 has y offset for vertical travel', function()
    local start = {x = 300, y = 100}
    local dest = {x = 300, y = 500}
    local curve = teleport_trail.generateCurve(start, dest)
    local p = teleport_trail.computeCurvePoint(curve, 0.5)
    assertNear(300, p.y, 1.0, 'midpoint y at t=0.5')
    assertTrue(p.x ~= 300, 'x should be offset from straight line at midpoint')
end)

test('generateCurve produces deterministic results for same inputs', function()
    local start = {x = 100, y = 200}
    local dest = {x = 500, y = 200}
    local curve1 = teleport_trail.generateCurve(start, dest)
    local curve2 = teleport_trail.generateCurve(start, dest)
    for t = 0, 1, 0.1 do
        local p1 = teleport_trail.computeCurvePoint(curve1, t)
        local p2 = teleport_trail.computeCurvePoint(curve2, t)
        assertNear(p1.x, p2.x, 0.001, 'deterministic x at t=' .. t)
        assertNear(p1.y, p2.y, 0.001, 'deterministic y at t=' .. t)
    end
end)

test('curve points stay close to straight line (bounded wobble)', function()
    local start = {x = 100, y = 200}
    local dest = {x = 500, y = 200}
    local curve = teleport_trail.generateCurve(start, dest)
    local straightDist = math.sqrt((dest.x - start.x)^2 + (dest.y - start.y)^2)
    for t = 0, 1, 0.05 do
        local p = teleport_trail.computeCurvePoint(curve, t)
        local distToLine = math.abs(p.y - 200) -- horizontal line, y=200
        -- Wobble amplitude should be reasonable (e.g., <= 15% of distance)
        assertTrue(distToLine < straightDist * 0.2, 'wobble amplitude bounded at t=' .. t)
    end
end)

test('calculateTravelDuration scales with distance', function()
    local d1 = teleport_trail.calculateTravelDuration(100)
    local d2 = teleport_trail.calculateTravelDuration(500)
    local d3 = teleport_trail.calculateTravelDuration(1000)
    assertTrue(d2 > d1, 'longer distance = longer duration')
    assertTrue(d3 > d2, 'longer distance = longer duration')
end)

test('calculateTravelDuration clamps to min/max', function()
    local minDur = teleport_trail.calculateTravelDuration(0)
    local maxDur = teleport_trail.calculateTravelDuration(10000)
    assertNear(0.5, minDur, 0.01, 'min duration 0.5s')
    assertNear(3.0, maxDur, 0.01, 'max duration 3s')
end)

test('calculateTravelDuration formula: base + 0.0025s per pixel', function()
    local base = 0.5
    local perPx = 0.0025
    local d = teleport_trail.calculateTravelDuration(100)
    local expected = base + perPx * 100
    assertNear(expected, d, 0.01, 'formula matches at 100px')
end)