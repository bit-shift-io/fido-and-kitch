local MenuState = Class{}

local input = {text = ""}

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

function MenuState:enter()
    print('menu enter')
end

function MenuState:exit()
end

function MenuState:update(dt)
	testUi()
end

function MenuState:draw()
	suit.draw()
    love.graphics.print("Menu. Press Enter to start. Esc to exit", 10, 10)
end

function MenuState:textinput(t)
end

function MenuState:keypressed(k)
    local game = self.entity
    if k == 'return' then
        game:setGameState('InGameState')
        game:load()
    end

    if k == 'escape' then
		love.event.push("quit")
	end
end


local InGameState = Class{}

function InGameState:enter()
    print('ingame enter')
end

function InGameState:load()
    if profile then
		profile.start()
	end

	-- files stored in game dir
	--function love.filesystem.isFused()
	--	return true
	--end
	--print(love.filesystem.isFused())

	world = World:new(0, 90.81, true)
	map = Map:new('res/map/sandbox.lua', world)

	camera = Camera(love.graphics.getWidth()/2,love.graphics.getHeight()/2, 1)

	-- spawn players
	self.players = {}
	local playerCount = 2
	local index = 1
	for li, layer in ipairs(map.map.layers) do -- todo: map.map changed with the new layout for some reason??
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
	local idx = utils.tableFind(self.players, player)
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

	--[[
	local tx = camera.x - (love.graphics.getWidth() / 2)
	local ty = camera.y - (love.graphics.getHeight() / 2)

	if tx < 0 then 
		tx = 0 
	end
	if tx > map.map.width  * map.map.tilewidth  - love.graphics.getWidth()  then
		tx = map.map.width  * map.map.tilewidth  - love.graphics.getWidth()  
	end
	if ty > map.map.height * map.map.tileheight - love.graphics.getHeight() then
		ty = map.map.height * map.map.tileheight - love.graphics.getHeight()
	end

	tx = math.floor(tx)
	ty = math.floor(ty)
	]]--

	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	local mw = map.map.width * map.map.tilewidth
	local mh = map.map.height * map.map.tileheight
	local sx = w / mw
	local sy = h / mh
	local s = math.min(sx, sy)

	-- todo: centre the map? why is there a black bar at the bottom?
	map.map:draw(0, 0, s, s)

	--[[
	camera:attach()
	map:draw()

    local physics_draw = (arg[#arg] == "debug") and true
	if physics_draw then
		world:draw()
	end
	camera:detach()
	]]--

end

function InGameState:keypressed(k)
    local game = self.entity
    if k == 'escape' then
        game:setGameState('MenuState')
    end
end


return {MenuState = MenuState, InGameState = InGameState}