-- Path component
-- just a simple path utility class

local Log = require("src.utils.log")

local Path = Class({})

function Path:init(props)
	self.type = "path"
	if props.polyline == nil then
		Log.warn("Bad object passed to Path! Pass an object that is a polyline")
		return -- error!
	end

	local curveTable = {}
	self.points = {}

	for i, p in ipairs(props.polyline) do
		local v = Vector(p.x, p.y)
		table.insert(self.points, v)

		table.insert(curveTable, p.x)
		table.insert(curveTable, p.y)
	end

	self.curve = love.math.newBezierCurve(curveTable)

	-- bezier curves arent linear in t, so sample the curve into a dense table
	-- at uniform arc-length intervals. This makes travel along the path a
	-- constant world speed instead of easing into/out of the authored points.
	-- The sampled table also gives us the true arc length for duration math.
	local SAMPLE_COUNT = 100
	self.samples = {}
	self.length = 0
	local prev
	for i = 0, SAMPLE_COUNT do
		local v = Vector(self.curve:evaluate(i / SAMPLE_COUNT))
		table.insert(self.samples, v)
		if prev then
			self.length = self.length + prev:dist(v)
		end
		prev = v
	end

	-- Build arc-length parameterization: cumulative distances at each sample
	self.arcLengths = { 0 }
	for i = 2, #self.samples do
		local dist = self.samples[i - 1]:dist(self.samples[i])
		self.arcLengths[i] = self.arcLengths[i - 1] + dist
	end
end

function Path:getPositionV(distance)
	if #self.samples == 0 then
		return Vector(0, 0)
	end

	-- distance is arc length along the curve (0 to self.length)
	local d = math.min(self.length, math.max(0, distance))

	-- Find the segment containing this distance
	local i = 1
	while i < #self.arcLengths and self.arcLengths[i + 1] < d do
		i = i + 1
	end

	if i >= #self.samples then
		return self.samples[#self.samples]:clone()
	end

	local segStart = self.arcLengths[i]
	local segEnd = self.arcLengths[i + 1]
	local segLen = segEnd - segStart

	if segLen <= 0 then
		return self.samples[i]:clone()
	end

	local f = (d - segStart) / segLen
	local a = self.samples[i]
	local b = self.samples[i + 1]
	return a + (b - a) * f
end

function Path:draw()
	if conf.debug == false then
		return
	end

	if self.curve == nil then
		return
	end

	love.graphics.line(self.curve:render())
end

return Path
