require("tests.support.headless_bootstrap")

local GameHud = require("src.ui.game_hud")

local internal = GameHud._internal

local MARGIN = 16

local function test(name, fn)
	fn()
	io.write("✓ " .. name .. "\n")
end

test("centerOffset centers a block", function()
	assert(internal.centerOffset(800, 100) == 350)
end)

test("centerOffset clamps to MARGIN when block fills window", function()
	assert(internal.centerOffset(800, 800) == 16)
end)

test("centerOffset clamps to MARGIN when block wider than window", function()
	assert(internal.centerOffset(800, 900) == 16)
end)

test("centerOffset of a tiny block", function()
	assert(internal.centerOffset(800, 16) == 392)
end)

test("heartRunWidth of 0 lives is 0", function()
	assert(internal.heartRunWidth(0) == 0)
end)

test("heartRunWidth of 1 life", function()
	assert(internal.heartRunWidth(1) == 48)
end)

test("heartRunWidth of 3 lives", function()
	assert(internal.heartRunWidth(3) == 176)
end)

test("coinSegmentWidth absent", function()
	assert(internal.coinSegmentWidth(false, 30) == 0)
end)

test("coinSegmentWidth present", function()
	assert(internal.coinSegmentWidth(true, 30) == 16 + 48 + 12 + 30)
end)

test("blockWidth without coins", function()
	assert(internal.blockWidth(3, false, 30) == 176)
end)

test("blockWidth with coins", function()
	assert(internal.blockWidth(3, true, 30) == 176 + 106)
end)

print("hud_centering_test: all assertions passed")
