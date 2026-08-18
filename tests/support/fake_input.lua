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

-- consumed by InputManager:pollGamepad (js:getAxis(1) / js:getAxis(2))
function Joystick:getAxis(axis)
	return self.axes[axis] or 0
end

function Joystick:isConnected()
	return true
end

function Joystick:isGamepad()
	-- generic joystick: raw axes + raw button indices, no gamepad-axis layer
	return false
end

function Joystick:getName()
	return 'Fake Joystick'
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
-- so the caller can drive its axes/buttons. Player:isDown routes through
-- inputManager:isDown, so the stick is also wired into the InputManager's
-- player slot -- under the real game love.joystickadded does that, but the
-- mock never fires joystick-added callbacks when the stick appears mid-run.
function FakeInput:assignJoystick(playerIndex)
	local joystick = newJoystick()
	self.state.joysticks[playerIndex] = joystick
	if inputManager and inputManager.players then
		inputManager.players[playerIndex].joystick = joystick
	end
	return joystick
end

-- press, step frames at a fixed 1/60s for `seconds`, then release.
local function holdFor(game, controller, key, seconds)
	controller:press(key)
	FrameStepper.step(game, FrameStepper.secondsToFrames(seconds))
	controller:release(key)
end

-- Window control methods for AI agents
local WindowControl = {}
WindowControl.__index = WindowControl

function WindowControl.new(controller)
	return setmetatable({controller = controller}, WindowControl)
end

function WindowControl:maximize()
	love.window.maximize()
end

function WindowControl:minimize()
	love.window.minimize()
end

function WindowControl:restore()
	love.window.restore()
end

function WindowControl:setFullscreen(fullscreen, fullscreentype)
	return love.window.setFullscreen(fullscreen, fullscreentype)
end

function WindowControl:getFullscreen()
	return love.window.getFullscreen()
end

function WindowControl:toggleFullscreen()
	local fs = love.window.getFullscreen()
	love.window.setFullscreen(not fs)
	return not fs
end

function WindowControl:setDimensions(width, height)
	love.window.setDimensions(width, height)
end

function WindowControl:getDimensions()
	return love.window.getDimensions()
end

function WindowControl:setPosition(x, y)
	love.window.setPosition(x, y)
end

function WindowControl:getPosition()
	return love.window.getPosition()
end

function WindowControl:setTitle(title)
	love.window.setTitle(title)
end

function WindowControl:getTitle()
	return love.window.getTitle()
end

function WindowControl:setMode(width, height, flags)
	return love.window.setMode(width, height, flags)
end

function WindowControl:getMode()
	return love.window.getMode()
end

function WindowControl:isMaximized()
	return love.window.isMaximized()
end

function WindowControl:isMinimized()
	return love.window.isMinimized()
end

function WindowControl:setVSync(vsync)
	love.window.setVSync(vsync)
end

function WindowControl:getVSync()
	return love.window.getVSync()
end

function WindowControl:setResizable(resizable)
	love.window.setResizable(resizable)
end

function WindowControl:isResizable()
	return love.window.isResizable()
end

function WindowControl:setBorderless(borderless)
	love.window.setBorderless(borderless)
end

function WindowControl:isBorderless()
	return love.window.isBorderless()
end

-- Attach window control to FakeInput instances
function FakeInput:window()
	return WindowControl.new(self)
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
