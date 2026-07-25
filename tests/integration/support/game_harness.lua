-- Bootstraps the same global classes src/main.lua wires up (Vector, Class,
-- Entity, Map, Player, ...), then starts a game directly in InGameState --
-- skipping MenuState/Slab entirely, per DECISIONS.md Q3: driving Slab menu
-- UI via simulated input is out of scope, so tests jump straight to the
-- state that actually loads the map/player/world stack.
local LoveMock = require('tests.integration.support.love_mock')

local GameHarness = {}

local globalsBooted = false

local function bootGlobals()
	if globalsBooted then
		return
	end
	globalsBooted = true

	tbl = require('src.utils.tbl')

	conf = require('conf')
	-- love.conf(t) is normally invoked by the LÖVE runtime itself before
	-- love.load, with `t` pre-seeded with these sub-tables for conf.lua to
	-- override -- outside LÖVE nobody calls it, so we replicate that here.
	love.conf({graphics = {}, window = {}, modules = {}, audio = {}})
	conf.args = {}

	str = require('src.utils.str')
	utils = require('src.utils.utils')

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
	Variable = require('src.components.variable')
	Map = require('src.map')
	AutoCamera = require('src.camera')
	Player = require('src.player.player')
end

-- Fresh love mock per game so keyboard/joystick state never leaks between
-- tests (or between successive games started within the same test).
function GameHarness.startGame(mapPath)
	love = LoveMock.new()
	bootGlobals()

	local GameStates = require('src.game_states')
	local game = {}
	game.fsm = StateMachine{stateClasses = GameStates, entity = game, currentState = 'InGameState'}

	function game:setGameState(name)
		self.fsm:setState(name)
	end

	function game:load(props)
		self.fsm:load(props)
	end

	function game:update(dt)
		self.fsm:update(dt)
	end

	game:load{map = mapPath}

	return game
end

return GameHarness
