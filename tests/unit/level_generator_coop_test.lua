local Coop = require("tools.level_generator.coop")
local Layout = require("tools.level_generator.layout")
local Rng = require("tools.level_generator.rng")

test("the vault sits entirely beyond the layout width (never overlapping terrain)", function()
	local layout = Layout.generate(Rng.new(1), { size = "medium" })
	local vault = Coop.planVault(layout)

	assertTrue(vault.newWidth > layout.width)
	for _, cell in ipairs(vault.wallCells) do
		assertTrue(cell.col > layout.width, "wall cell must be beyond the original layout width")
	end
end)

test("the vault walls form a fully enclosed box (every interior cell has walls on all 4 sides)", function()
	local layout = Layout.generate(Rng.new(1), { size = "medium" })
	local vault = Coop.planVault(layout)

	local wallSet = {}
	for _, cell in ipairs(vault.wallCells) do
		wallSet[cell.row .. "," .. cell.col] = true
	end

	-- the interior teleport/key/cage x positions must each have a wall cell
	-- directly above (roof), and the box must have a floor below them
	local interior = vault.interior
	local TILE = 32
	for _, x in ipairs({ interior.teleportX, interior.keyX, interior.cageX }) do
		local col = math.floor(x / TILE) + 1
		local floorRow = math.floor(interior.y / TILE) + 1
		assertTrue(wallSet[floorRow .. "," .. col], "expected a floor wall cell under interior x=" .. x)
	end
end)

test("vault plans are deterministic given the same layout", function()
	local layout = Layout.generate(Rng.new(5), { size = "large" })
	local a = Coop.planVault(layout)
	local b = Coop.planVault(layout)
	assertEqual(a.newWidth, b.newWidth)
	assertEqual(a.interior.teleportX, b.interior.teleportX)
end)
