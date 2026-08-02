local MapList = require('src.ui.map_list')
local BaseState = require('src.states.base_state')
local Log = require('src.utils.log')

local MenuState = Class{__includes = {Entity, BaseState}}

function MenuState:enter()
    Log.debug('menu enter')
    self.mapList = MapList{dir='res/map'}
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

    for i = 1, 4 do
        if inputManager:wasPressed(i, 'left') then
            self.mapList:previous()
            break
        elseif inputManager:wasPressed(i, 'right') then
            self.mapList:next()
            break
        elseif inputManager:wasPressed(i, 'start') or inputManager:wasPressed(i, 'use') then
            self:startGame{map=self.mapList.selectedFile}
            break
        elseif inputManager:wasPressed(i, 'back') then
            love.event.push('quit')
            break
        end
    end
end

function MenuState:draw()
    self.mapList:draw()
end

function MenuState:keypressed(k)
    if k == 'return' or k == 'space' then
        self:startGame{map=self.mapList.selectedFile}
    elseif k == 'escape' then
        love.event.push('quit')
    end
end

function MenuState:mousepressed(x, y, button)
    if button ~= 1 then return end
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

return MenuState