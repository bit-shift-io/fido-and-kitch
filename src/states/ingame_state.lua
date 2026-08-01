local Lives = require('src.player.lives')
local LivesHud = require('src.ui.lives_hud')
local AutoCamera = require('src.camera')
local EventBus = require('src.utils.event_bus')
local DebugOverlay = require('src.ui.debug_overlay')
local BaseState = require('src.states.base_state')
local Log = require('src.utils.log')

local InGameState = Class{__includes = BaseState}

local GAME_OVER_ZOOM_DELAY = 0.6

function InGameState:enter()
    Log.debug('ingame enter')
end

function InGameState:load(props)
    if profile then
        profile.start()
    end

    self.currentMap = props.map or 'res/map/sandbox.tmx'

    _G.world = World:new(0, 90.81, true)
    _G.map = Map:new(self.currentMap, world, true)

    local mapW, mapH = map:getPixelSize()
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

    -- Debug overlay
    self.debugOverlay = DebugOverlay:new()

    self.players = {}
    local playerCount = 2
    local index = 1
    for li, layer in ipairs(map.layers) do
        if layer.type == "objectgroup" then
            for _, object in ipairs(layer.objects) do
                if object.type == 'spawn' then
                    for i = 1, playerCount, 1 do
                        local entity = Player{object=object, index=index}
                        entity.destroySignal:connect(utils.bindSelf(InGameState.onPlayerDestroyed, self))
                        entity:startSpawnFlash()
                        table.insert(layer.entities, entity)
                        table.insert(self.players, entity)
                        index = index + 1
                    end
                end
            end
        end
    end

    -- Listen for player deaths via EventBus
    EventBus.on('player_died', utils.bindSelf(InGameState.onPlayerDied, self))

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
    Log.debug('player destroyed')
    local idx = tbl.findIndexEq(self.players, player)
    table.remove(self.players, idx)

    local playerCount = #self.players
    if playerCount == 0 then
        Log.debug('all players have left the map!')
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
    local tx, ty, sx, sy = self.camera:getDrawParams()
    map:draw2(tx, ty, sx, sy)
    map:drawEntities(tx, ty, sx, sy)

    -- Debug overlay (hitboxes, ladders, kill zones, safe positions, etc.)
    if conf.drawphysics and self.debugOverlay then
        self.debugOverlay.enabled = true
        local targets = self:collectPlayerTargets()
        local cameraFramingBounds = self.camera:computeTargetView(targets)
        self.debugOverlay:draw(world, map, self.players, tx, ty, sx, sy, cameraFramingBounds)
    else
        self.debugOverlay.enabled = false
    end

    self.livesHud:draw()
end

function InGameState:resize(w, h)
    if map then
        map:resize(w, h)
    end

    if self.camera then
        self.camera:setScreenSize(w, h)
        local mapW, mapH = map:getPixelSize()
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

return InGameState