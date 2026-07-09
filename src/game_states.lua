local MapList = require('src.ui.map_list')

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

	world = World:new(0, 90.81, true)
	map = Map:new(props.map or 'res/map/sandbox.lua', world, true)
	camera = Camera(love.graphics.getWidth()/2,love.graphics.getHeight()/2, 1)

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

return {MenuState = MenuState, InGameState = InGameState}