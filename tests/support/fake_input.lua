-- Drives a fake keyboard/joystick state the way a human would: press/release
-- keys, and set a fake joystick's axes/buttons per player index. Built on
-- top of the *current* global `love` set by GameHarness, so construct a
-- FakeInput only after GameHarness.startGame() has run.
--
-- Under the integration tier, love.keyboard/love.joystick are already the
-- mock's fakes reading love._state (see tests/support/love_mock.lua) -- this
-- module just drives that state. Under the e2e tier, love.keyboard and
-- love.joystick are real LÖVE's genuine implementations, so FakeInput.new()
-- overwrites love.keyboard.isDown and love.joystick.getJoysticks with shims
-- reading its own state, sitting in front of the real ones for the rest of
-- the process -- physical keyboard/gamepad input never reaches an entity's
-- input query (see DECISIONS.md Q13).
local FrameStepper = require('tests.support.frame_stepper')

local Joystick = {}
Joystick.__index = Joystick

local function newJoystick()
	return setmetatable({axes = {0, 0}, buttons = {}}, Joystick)
end

-- consumed by Player:isDown via love.joystick.getJoysticks()[index]:getAxes()
function Joystick:getAxes()
	return self.axes[1], self.axes[2]
end

-- consumed by Player:isDown via love.joystick.getJoysticks()[index]:isDown(1)
function Joystick:isDown(button)
	return self.buttons[button] == true
end

function Joystick:setAxes(horizontal, vertical)
	self.axes = {horizontal, vertical}
end

function Joystick:setButtonDown(button, isDown)
	self.buttons[button] = isDown
end

local FakeInput = {}
FakeInput.__index = FakeInput

function FakeInput.new()
	local state = love._state or {keysDown = {}, joysticks = {}}
	love._state = state

	love.keyboard.isDown = function(key)
		return state.keysDown[key] == true
	end

	love.joystick.getJoysticks = function()
		return state.joysticks
	end

	return setmetatable({state = state}, FakeInput)
end

function FakeInput:press(key)
	self.state.keysDown[key] = true
end

function FakeInput:release(key)
	self.state.keysDown[key] = nil
end

-- assigns a fresh fake joystick to a player index (matching
-- love.joystick.getJoysticks()[playerIndex] in Player:isDown) and returns it
-- so the caller can drive its axes/buttons.
function FakeInput:assignJoystick(playerIndex)
	local joystick = newJoystick()
	self.state.joysticks[playerIndex] = joystick
	return joystick
end

-- press, step frames at a fixed 1/60s for `seconds`, then release.
local function holdFor(game, controller, key, seconds)
	controller:press(key)
	FrameStepper.step(game, FrameStepper.secondsToFrames(seconds))
	controller:release(key)
end

-- steps frames until predicate() is true, or fails the test if maxFrames is
-- exhausted without it becoming true.
local function runUntil(game, predicate, maxFrames)
	for _ = 1, maxFrames do
		FrameStepper.step(game, 1)
		if predicate() then
			return
		end
	end
	error(string.format('runUntil: predicate not satisfied within %d frames', maxFrames))
end

return {
	FakeInput = FakeInput,
	holdFor = holdFor,
	runUntil = runUntil,
}
