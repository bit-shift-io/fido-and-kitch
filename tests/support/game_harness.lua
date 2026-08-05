-- Bootstraps the same global classes src/main.lua wires up (Vector, Class,
-- Entity, Map, Player, ...), then starts a game directly in InGameState --
-- skipping MenuState/Slab entirely, per DECISIONS.md Q3: driving Slab menu
-- UI via simulated input is out of scope, so tests jump straight to the
-- state that actually loads the map/player/world stack.
local LoveMock = require('tests.support.love_mock')

local GameHarness = {}

local globalsBooted = false

-- Under real LÖVE (isReal = true) the engine itself already invoked
-- love.conf(t) and src/main.lua already set conf.args from the real launch
-- arguments before handing off to the e2e runner -- redoing either here
-- would stomp on real window/module setup rather than just replicate it, so
-- that block is skipped entirely in that mode (see DECISIONS.md Q11).
local function bootGlobals(isReal)
	if globalsBooted then
		return
	end
	globalsBooted = true

	tbl = require('src.utils.tbl')

	if not isReal then
		conf = require('conf')
		-- love.conf(t) is normally invoked by the LÖVE runtime itself before
		-- love.load, with `t` pre-seeded with these sub-tables for conf.lua to
		-- override -- outside LÖVE nobody calls it, so we replicate that here.
		love.conf({graphics = {}, window = {}, modules = {}, audio = {}})
		conf.args = {}
	end

	str = require('src.utils.str')
	utils = require('src.utils.utils')
	Log = require('src.utils.log')

	Vector = require('lib.hump.vector')
	Class = require('lib.hump.class')
	Tween = require('lib.tween.tween')

	Rect = require('src.utils.rect')
	Signal = require('src.utils.signal')
	World = require('src.world')
	Entity = require('src.entity')
	StateMachine = require('src.components.state_machine')
	Sprite = require('src.components.sprite')
	Path = require('src.components.path')
	Timeline = require('src.components.timeline')
	PathFollow = require('src.components.path_follow')
	Collider = require('src.components.collider')
	Pickup = require('src.components.pickup')
	Inventory = require('src.components.inventory')
	Usable = require('src.components.usable')
	Switchable = require('src.components.switchable')
	Variable = require('src.components.variable')
	Sound = require('src.components.sound')
	Map = require('src.map')
	AutoCamera = require('src.camera')
	Player = require('src.player.player')
	InputManager = require('src.input.input_manager')
end

-- Fresh love mock per game so keyboard/joystick state never leaks between
-- tests (or between successive games started within the same test).
-- Pass {real = true} under the e2e tier to start against the real `love`
-- global the engine already provided instead of installing the mock.
function GameHarness.startGame(mapPath, opts)
	opts = opts or {}

	if not opts.real then
		_G.love = LoveMock.new()
	end
	bootGlobals(opts.real)

	-- Create InputManager instance (same as main.lua)
	inputManager = InputManager()

	local MenuState = require('src.states.menu_state')
	local InGameState = require('src.states.ingame_state')
	local GameOverState = require('src.states.game_over_state')
	local game = {}
	game.fsm = StateMachine{stateClasses = {MenuState = MenuState, InGameState = InGameState, GameOverState = GameOverState}, entity = game, currentState = 'InGameState'}

	function game:setGameState(name)
		self.fsm:setState(name)
	end

	function game:load(props)
		self.fsm:load(props)
	end

	function game:update(dt)
		io.stderr:write("DEBUG game:update dt = " .. type(dt) .. " " .. tostring(dt) .. "\n")
		io.stderr:flush()
		inputManager:update(dt)
		self.fsm:update(dt)
	end

	function game:draw()
		self.fsm:draw()
	end

	game:load{map = mapPath}

	-- Lets the e2e runner (tests/e2e/run.lua) know which game object to
	-- render every real drawn frame and capture from; a no-op hook outside
	-- the e2e tier.
	if opts.real and _G.E2E_ON_GAME_STARTED then
		_G.E2E_ON_GAME_STARTED(game)
	end

	return game
end

return GameHarness
