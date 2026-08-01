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
    self.map = props and props.map or 'res/map/sandbox.tmx'
end

function GameOverState:exit()
end

function GameOverState:update(dt)
    for i = 1, 4 do
        if inputManager:wasPressed(i, 'up') then
            self:moveSelection(-1)
            break
        elseif inputManager:wasPressed(i, 'down') then
            self:moveSelection(1)
            break
        elseif inputManager:wasPressed(i, 'start') or inputManager:wasPressed(i, 'use') then
            self:activateSelected()
            break
        end
    end
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
end

function GameOverState:joystickpressed(joystick, button)
end

function GameOverState:mousepressed(x, y, button)
    if button ~= 1 then return end
    self:handlePress(x, y)
end

function GameOverState:touchpressed(id, x, y)
    self:handlePress(x, y)
end

function GameOverState:textinput(t)
end

return GameOverState