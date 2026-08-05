-- Headless alpha-state machine coverage for GameHud. love stays nil unless a
-- test needs it (draw smoke); the draw test installs LoveMock.new(), and the
-- mock needs a no-op love.graphics.print (Task 6). EventBus signals persist
-- across tests in one process, so each test clears them first.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local LoveMock = require('tests.support.love_mock')
local EventBus = require('src.utils.event_bus')

local GameHud = require('src.ui.game_hud')

local FADE_FRAMES = 72   -- 1.2s at 1/60
local HOLD_FRAMES = 120  -- 2.0s at 1/60

local function makeHud()
	local mode = 'follow'
	local hud = GameHud{
		getLives = function() return 3 end,
		getCoins = function() return 1 end,
		getTotal = function() return 3 end,
		getCameraMode = function() return mode end,
		livesHud = {draw = function() end},
	}
	local function setMode(next)
		mode = next
	end
	return hud, setMode
end

local function step(hud, frames)
	for _ = 1, frames do
		hud:update(1 / 60)
	end
end

test('the HUD stays hidden in follow mode', function()
	EventBus.clear()
	local hud = makeHud()
	step(hud, 120)
	assertEqual(0, hud.alpha, 'expected alpha 0 in follow mode')
end)

test('the HUD is fully opaque in overview mode', function()
	EventBus.clear()
	local hud, setMode = makeHud()
	setMode('overview')
	step(hud, 1)
	assertEqual(1, hud.alpha, 'expected alpha 1 in overview mode')
end)

test('a coin pickup fades the HUD in, holds, then fades back out', function()
	EventBus.clear()
	local hud = makeHud()

	EventBus.emit('coin_collected', {x = 130, y = 170})
	step(hud, FADE_FRAMES)
	assertEqual(1, hud.alpha, 'expected the HUD to reach full opacity after a pickup')

	step(hud, HOLD_FRAMES - FADE_FRAMES)
	assertEqual(1, hud.alpha, 'expected the HUD to hold while the timer runs')

	step(hud, FADE_FRAMES)
	assertEqual(0, hud.alpha, 'expected the HUD to fade back out')
end)

test('a life lost also fades the HUD in', function()
	EventBus.clear()
	local hud = makeHud()

	EventBus.emit('player_died', {player = {}, deathType = 'water'})
	step(hud, FADE_FRAMES)
	assertEqual(1, hud.alpha, 'expected player_died to fade the HUD in')
end)

test('drawing with coins collected renders under the love mock', function()
	EventBus.clear()
	local prevLove = love
	love = LoveMock.new()
	local hud = makeHud()

	EventBus.emit('coin_collected', {x = 130, y = 170})
	step(hud, FADE_FRAMES)
	assertEqual(1, hud.alpha, 'expected full opacity before drawing')
	hud:draw()
	love = prevLove
end)
