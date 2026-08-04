tbl = require('src.utils.tbl')

-- IPC log capture: intercept print() so GET_LOG can retrieve console output
if not _ipc_log then
	_ipc_log = {}
	_ipc_log_max = 500
	_original_print = print
	function print(...)
		_original_print(...)
		local parts = {}
		for i = 1, select('#', ...) do
			parts[#parts + 1] = tostring(select(i, ...))
		end
		local msg = table.concat(parts, '\t')
		_ipc_log[#_ipc_log + 1] = msg
		if #_ipc_log > _ipc_log_max then
			table.remove(_ipc_log, 1)
		end
	end
end

if tbl.includes(arg, 'debug') then
	local ok, debugger = pcall(require, 'lldebugger')
	if ok then
		debugger.start()
	else
		print('lldebugger not found; continuing without debugger')
	end
end

if tbl.includes(arg, 'profile') then
	profile = require('src.utils.profile')
end

-- includes
--require('lovedebug')

-- global includes to save having to include in other files!
conf = require('conf')
str = require('src.utils.str')
utils = require('src.utils.utils')
Log = require('src.utils.log')

Vector = require('lib.hump.vector')
Class = require('lib.hump.class')
Tween = require('lib.tween.tween')
--suit = require('lib.suit')
--urutora = require('lib.urutora')
Slab = require('lib.Slab')

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
Sound = require('src.components.sound')
Particles = require('src.particles')
FxManager = require('src.fx.manager')
CoinPickup = require('src.fx.coin_pickup')
DustBurst = require('src.fx.dust_burst')
SparkTrail = require('src.fx.spark_trail')
Map = require('src.map')
Player = require('src.player.player')
Game = require('src.game')
InputManager = require('src.input.input_manager')


-- local includes only accessible to this file

function setupConf(args)
	conf.args = args
    conf.drawphysics = tbl.includes(conf.args, 'drawphysics')
	conf.debug = tbl.includes(conf.args, 'debug')
    conf.ipc_enabled = tbl.includes(conf.args, 'ipc')
    local portArg = tbl.find(conf.args, function(e) return str.startsWith(e, 'ipc_port=') end)
    if portArg then
        conf.ipc_port = tonumber(str.split(portArg, '=')[2]) or 8080
    end
    -- `love . debug` also turns on Log.debug's per-action gameplay chatter
    -- (state enters, "X has been used", pickups, ...), silent otherwise
    Log.level = conf.debug and 'debug' or 'info'
end

-- e2e=<path/to/scenario_test.lua>, following the same launch-argument style
-- as map=/debug/drawphysics. Detected by src/main.lua so the entry point
-- can hand control to the e2e runner instead of constructing the normal
-- Game (DECISIONS.md Q11).
local function findE2ETestFile(args)
	local e2eArg = tbl.find(args, function(e) return str.startsWith(e, 'e2e=') end)
	if not e2eArg then
		return nil
	end
	return str.split(e2eArg, '=')[2]
end

function love.load(args)
	setupConf(args)
	love.graphics.setDefaultFilter('linear', 'linear')

	local e2eTestFile = findE2ETestFile(args)
	if e2eTestFile then
		-- requiring tests.e2e.run defines its own love.update/love.draw/
		-- love.quit, replacing the ones below for the rest of this process.
		local E2ERunner = require('tests.e2e.run')
		E2ERunner.start(e2eTestFile, args)
		return
	end

	Slab.Initialize(args)
	--u = urutora:new()
	game = Game()
	inputManager = InputManager()

	if conf.ipc_enabled then
		ipc = require('src.ipc.init')
		ipc.start(conf.ipc_port or 8080)
	end
end

function love.update(dt)
	if ipc then
		ipc.update(dt)
	end
	if game then
		inputManager:update(dt)
		game:update(dt)
	end
end

function love.draw()
	if game then
		game:draw()
	end
end

function love.resize(w, h)
	if game then
		game:resize(w, h)
	end
end

function love.keypressed(k)
	if game then
		game:keypressed(k)
	end
end

function love.joystickadded(joystick)
	if inputManager then
		inputManager:joystickadded(joystick)
	end
end

function love.joystickremoved(joystick)
	if inputManager then
		inputManager:joystickremoved(joystick)
	end
end

function love.gamepadpressed(joystick, button)
	if game then
		game:gamepadpressed(joystick, button)
	end
end

function love.joystickpressed(joystick, button)
	if joystick:isGamepad() then
		return
	end
	if game then
		game:joystickpressed(joystick, button)
	end
end

function love.mousepressed(x, y, button)
	if game then
		game:mousepressed(x, y, button)
	end
end

function love.touchpressed(id, x, y)
	if game then
		game:touchpressed(id, x, y)
	end
end

function love.textinput(t)
	if game then
		game:textinput(t)
	end
end

function love.quit()
	if ipc then
		ipc.stop()
	end
end


