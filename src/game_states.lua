local MapList = require('src.ui.map_list')
local Lives = require('src.player.lives')
local LivesHud = require('src.ui.lives_hud')

local MenuState = Class{__includes = Entity}

--[[
function testUi()
	-- put the layout origin at position (100,100)
	-- the layout will grow down and to the right from this point
	suit.layout:reset(100,100)

	-- put an input widget at the layout origin, with a cell size of 200 by 30 pixels
	suit.Input(input, suit.layout:row(200,30))

	-- put a label that displays the text below the first cell
	-- the cell size is the same as the last one (200x30 px)
	-- the label text will be aligned to the left
	suit.Label("Hello, "..input.text, {align = "left"}, suit.layout:row())

	-- put an empty cell that has the same size as the last cell (200x30 px)
	suit.layout:row()

	-- put a button of size 200x30 px in the cell below
	-- if the button is pressed, quit the game
	if suit.Button("Quit", suit.layout:row()).hit then
		love.event.quit()
	end
end
]]--

function MenuState:enter()
    print('menu enter')
	self.mapList = MapList{dir='res/map'} --self:addComponent(MapList())
end

function MenuState:exit()
end

function MenuState:startGame(props)
	local game = self.entity
	game:setGameState('InGameState')
	game:load(props)
end

function MenuState:update(dt)
	Entity.update(self, dt)

	local action = self.mapList:update(dt)
	if action == 'start' then
		self:startGame{map=self.mapList.selectedFile}
	elseif action == 'back' then
		love.event.push('quit')
	end
end

function MenuState:draw()
	self.mapList:draw()
end

function MenuState:resize(w, h)
end

function MenuState:textinput(t)
end

function MenuState:keypressed(k)
    if k == 'return' or k == 'space' then
        self:startGame{map=self.mapList.selectedFile}
    elseif k == 'left' or k == 'a' then
		self.mapList:previous()
    elseif k == 'right' or k == 'd' then
		self.mapList:next()
    elseif k == 'escape' then
		love.event.push('quit')
	end
end

function MenuState:gamepadpressed(joystick, button)
	local action = self.mapList:gamepadpressed(button)
	if action == 'start' then
		self:startGame{map=self.mapList.selectedFile}
	elseif action == 'back' then
		love.event.push('quit')
	end
end

function MenuState:joystickpressed(joystick, button)
	local action = self.mapList:joystickpressed(button)
	if action == 'start' then
		self:startGame{map=self.mapList.selectedFile}
	elseif action == 'back' then
		love.event.push('quit')
	end
end

function MenuState:mousepressed(x, y, button)
	if button ~= 1 then
		return
	end

	local action = self.mapList:pressed(x, y)
	if action == 'start' then
		self:startGame{map=self.mapList.selectedFile}
	end
end

function MenuState:touchpressed(id, x, y)
	local action = self.mapList:pressed(x, y)
	if action == 'start' then
		self:startGame{map=self.mapList.selectedFile}
	end
end


local InGameState = Class{}

function InGameState:enter()
    print('ingame enter')
end

function InGameState:load(props)
    if profile then
		profile.start()
	end

	-- files stored in game dir
	--function love.filesystem.isFused()
	--	return true
	--end
	--print(love.filesystem.isFused())

	self.currentMap = props.map or 'res/map/sandbox.lua'

	world = World:new(0, 90.81, true)
	map = Map:new(self.currentMap, world, true)
	camera = Camera(love.graphics.getWidth()/2,love.graphics.getHeight()/2, 1)

	self.lives = Lives.defaultCount()
	local ingame = self
	self.livesHud = LivesHud{getLives=function() return ingame.lives end}

	-- spawn players
	self.players = {}
	local playerCount = 2
	local index = 1
	for li, layer in ipairs(map.layers) do -- todo: map.map changed with the new layout for some reason??
		if layer.type == "objectgroup" then
			for _, object in ipairs(layer.objects) do
				if object.type == 'spawn' then
					for i = 1, playerCount, 1 do
						local entity = Player{object=object, index=index}
						entity.destroySignal:connect(utils.func(InGameState.onPlayerDestroyed, self))
						entity.deathSignal:connect(utils.func(InGameState.onPlayerDied, self))
						entity:startSpawnFlash()
						table.insert(layer.entities, entity)
						table.insert(self.players, entity)
						index = index + 1
					end
				end
			end
		end
	end

	if profile then
		profile.stop()
		print('love.load profile:')
		print(profile.report(10))
	end
end

function InGameState:onPlayerDied(player, deathType)
	local result = Lives.applyDeath(self.lives)
	self.lives = result.lives

	if result.outcome == 'gameover' then
		self:onGameOver()
	else
		player:respawn()
	end
end

function InGameState:onGameOver()
	local game = self.entity
	game:setGameState('GameOverState')
	game:load{map=self.currentMap}
end

function InGameState:onPlayerDestroyed(player)
	print('player destroyed')
	local idx = tbl.findIndexEq(self.players, player)
	table.remove(self.players, idx)

	local playerCount = #self.players
	if (playerCount == 0) then
		print('all players have left the map!')
		local game = self.entity
        game:setGameState('MenuState')
	end
end

function InGameState:exit()
end

function InGameState:update(dt)
	map:update(dt)
	world:update(dt)
end

function InGameState:draw()
	map:draw()
	--world:draw()
	self.livesHud:draw()
end

function InGameState:resize(w, h)
	if map then
		map:resize(w, h)
	end

	if camera then
		camera = Camera(w/2, h/2, 1)
	end
end

function InGameState:keypressed(k)
    local game = self.entity
    if k == 'escape' then
        game:setGameState('MenuState')
    end
end

function InGameState:gamepadpressed(joystick, button)
end

function InGameState:joystickpressed(joystick, button)
end

function InGameState:mousepressed(x, y, button)
end

function InGameState:touchpressed(id, x, y)
end

function InGameState:textinput(t)
end


local GameOverState = Class{}

local GAME_OVER_OPTIONS = {
	{id='restart', label='Restart Level'},
	{id='menu', label='Main Menu'},
}

function GameOverState:enter()
	print('gameover enter')
	self.selected = 1
	self.buttonRects = {}
	self.titleFont = love.graphics.newFont(30)
	self.bodyFont = love.graphics.newFont(20)
end

function GameOverState:load(props)
	self.map = props and props.map or 'res/map/sandbox.lua'
end

function GameOverState:exit()
end

function GameOverState:update(dt)
end

function GameOverState:moveSelection(delta)
	local count = #GAME_OVER_OPTIONS
	self.selected = ((self.selected - 1 + delta) % count) + 1
end

function GameOverState:activate(id)
	local game = self.entity
	if id == 'restart' then
		game:setGameState('InGameState')
		game:load{map=self.map}
	elseif id == 'menu' then
		game:setGameState('MenuState')
	end
end

function GameOverState:activateSelected()
	self:activate(GAME_OVER_OPTIONS[self.selected].id)
end

function GameOverState:handlePress(x, y)
	for id, rect in pairs(self.buttonRects) do
		if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
			self:activate(id)
			return
		end
	end
end

function GameOverState:draw()
	local lg = love.graphics
	local w = lg.getWidth()
	local h = lg.getHeight()
	self.buttonRects = {}

	lg.setColor(0, 0, 0, 0.85)
	lg.rectangle('fill', 0, 0, w, h)

	lg.setFont(self.titleFont)
	lg.setColor(1, 0.25, 0.25, 1)
	lg.printf('GAME OVER', 0, h * 0.3, w, 'center')

	lg.setFont(self.bodyFont)
	local optionHeight = 40
	local optionWidth = 260
	local startY = h * 0.3 + 80
	for i, option in ipairs(GAME_OVER_OPTIONS) do
		local y = startY + (i - 1) * (optionHeight + 16)
		local x = (w - optionWidth) * 0.5
		self.buttonRects[option.id] = {x=x, y=y, w=optionWidth, h=optionHeight}

		if i == self.selected then
			lg.setColor(1, 0.86, 0.22, 1)
		else
			lg.setColor(1, 1, 1, 0.78)
		end
		lg.printf(option.label, x, y + ((optionHeight - self.bodyFont:getHeight()) * 0.5), optionWidth, 'center')
	end

	lg.setColor(1, 1, 1, 1)
end

function GameOverState:resize(w, h)
end

function GameOverState:keypressed(k)
	if k == 'up' or k == 'w' then
		self:moveSelection(-1)
	elseif k == 'down' or k == 's' then
		self:moveSelection(1)
	elseif k == 'return' or k == 'space' then
		self:activateSelected()
	end
end

function GameOverState:gamepadpressed(joystick, button)
	if button == 'dpup' or button == 'leftshoulder' then
		self:moveSelection(-1)
	elseif button == 'dpdown' or button == 'rightshoulder' then
		self:moveSelection(1)
	elseif button == 'a' or button == 'start' then
		self:activateSelected()
	end
end

function GameOverState:joystickpressed(joystick, button)
	if button == 1 then
		self:activateSelected()
	elseif button == 2 then
		-- no back action on this screen
	elseif button == 5 then
		self:moveSelection(-1)
	elseif button == 6 then
		self:moveSelection(1)
	end
end

function GameOverState:mousepressed(x, y, button)
	if button ~= 1 then
		return
	end
	self:handlePress(x, y)
end

function GameOverState:touchpressed(id, x, y)
	self:handlePress(x, y)
end

function GameOverState:textinput(t)
end


return {MenuState = MenuState, InGameState = InGameState, GameOverState = GameOverState}