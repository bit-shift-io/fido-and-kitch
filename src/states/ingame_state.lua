local Lives = require('src.player.lives')
local LivesHud = require('src.ui.lives_hud')
local AutoCamera = require('src.camera')

local InGameState = Class{}

local GAME_OVER_ZOOM_DELAY = 0.6

function InGameState:enter()
    print('ingame enter')
end

function InGameState:load(props)
    if profile then
        profile.start()
    end

    self.currentMap = props.map or 'res/map/sandbox.tmx'

    _G.world = World:new(0, 90.81, true)
    _G.map = Map:new(self.currentMap, world, true)

    local mapW = map.map.width * map.map.tilewidth
    local mapH = map.map.height * map.map.tileheight
    self.camera = AutoCamera.new{
        screenW = love.graphics.getWidth(),
        screenH = love.graphics.getHeight(),
        mapW = mapW,
        mapH = mapH,
        tileW = map.map.tilewidth,
        tileH = map.map.tileheight,
    }
    self.gameOverTimer = nil

    self.lives = Lives.defaultCount()
    local ingame = self
    self.livesHud = LivesHud{getLives=function() return ingame.lives end}

    self.players = {}
    local playerCount = 2
    local index = 1
    for li, layer in ipairs(map.layers) do
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
    if self.gameOverTimer then
        return
    end

    self.camera:setMode('gameover')
    self.gameOverTimer = GAME_OVER_ZOOM_DELAY
end

function InGameState:transitionToGameOver()
    local game = self.entity
    game:setGameState('GameOverState')
    game:load{map=self.currentMap}
end

function InGameState:onPlayerDestroyed(player)
    print('player destroyed')
    local idx = tbl.findIndexEq(self.players, player)
    table.remove(self.players, idx)

    local playerCount = #self.players
    if playerCount == 0 then
        print('all players have left the map!')
        local game = self.entity
        game:setGameState('MenuState')
    end
end

function InGameState:exit()
end

function InGameState:collectPlayerTargets()
    local targets = {}
    for _, player in ipairs(self.players) do
        local bounds = player.collider:getBounds()
        table.insert(targets, {x = bounds.left, y = bounds.top, w = bounds.width, h = bounds.height})
    end
    return targets
end

function InGameState:updateDeathFramingTargets()
    for _, player in ipairs(self.players) do
        if player:isDead() then
            local bounds = player.collider:getBounds()
            local safePosition = player.safePosition
            self.camera:addExtraTarget(player, {
                x = safePosition.x - bounds.width / 2,
                y = safePosition.y - bounds.height / 2,
                w = bounds.width,
                h = bounds.height,
            })
        else
            self.camera:removeExtraTarget(player)
        end
    end
end

function InGameState:update(dt)
    map:update(dt)
    world:update(dt)

    if self.gameOverTimer then
        self.gameOverTimer = self.gameOverTimer - dt
        self.camera:update(dt, self:collectPlayerTargets())
        if self.gameOverTimer <= 0 then
            self:transitionToGameOver()
        end
    else
        self:updateDeathFramingTargets()
        self.camera:update(dt, self:collectPlayerTargets())
    end

    if inputManager:wasPressed(1, 'back') then
        self.camera:toggleOverview()
    end
end

function InGameState:draw()
    local lg = love.graphics
    local tx, ty, sx, sy = self.camera:getDrawParams()
    map:draw2(tx, ty, sx, sy)

    lg.push()
    lg.origin()
    lg.translate(math.floor(tx or 0), math.floor(ty or 0))
    lg.scale(sx or 1, sy or sx or 1)

    for _, layer in ipairs(map.layers) do
        if layer.type == "objectgroup" and layer.entities then
            for _, entity in ipairs(layer.entities) do
                entity:draw()
            end
        end
    end

    lg.pop()

    self.livesHud:draw()
end

function InGameState:resize(w, h)
    if map then
        map:resize(w, h)
    end

    if self.camera then
        self.camera:setScreenSize(w, h)
        local mapW = map.map.width * map.map.tilewidth
        local mapH = map.map.height * map.map.tileheight
        self.camera:setMapSize(mapW, mapH)
    end
end

function InGameState:keypressed(k)
    local game = self.entity
    if k == 'escape' then
        game:setGameState('MenuState')
    elseif k == 'space' then
        self.camera:toggleOverview()
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

return InGameState