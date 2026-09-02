local Pushables = require("tools.level_generator.pushables")
local Layout = require("tools.level_generator.layout")
local Rng = require("tools.level_generator.rng")

local TILE = 32

test("the gap column sits exactly one past the ground zone, and the far platform starts right after it", function()
	local layout = Layout.generate(Rng.new(1), { size = "medium" })
	local bridge = Pushables.planBoxBridge(layout)

	assertEqual(layout.width + 1, bridge.holeCol)
	assertTrue(bridge.newWidth > bridge.holeCol, "expected a far platform beyond the hole")
end)

test("the box spawns on solid ground immediately left of the gap, with a clear run-up", function()
	local layout = Layout.generate(Rng.new(1), { size = "medium" })
	local bridge = Pushables.planBoxBridge(layout)

	local boxCol = math.floor(bridge.boxSpawnX / TILE) + 1
	assertTrue(boxCol <= layout.width, "box must start on the existing ground zone, not past it")
	assertTrue(boxCol >= layout.width - 2, "box should start near the edge, not far back")
end)

test("a kill zone guards the gap so falling in before bridging it is recoverable, not a permanent stranding", function()
	local layout = Layout.generate(Rng.new(1), { size = "medium" })
	local bridge = Pushables.planBoxBridge(layout)

	assertTrue(bridge.killZone ~= nil)
	local holeLeftPx = (bridge.holeCol - 1) * TILE
	assertEqual(holeLeftPx, bridge.killZone.x)
end)

test("deterministic given the same layout", function()
	local layout = Layout.generate(Rng.new(2), { size = "large" })
	local a = Pushables.planBoxBridge(layout)
	local b = Pushables.planBoxBridge(layout)
	assertEqual(a.newWidth, b.newWidth)
	assertEqual(a.farObjectiveX, b.farObjectiveX)
end)
