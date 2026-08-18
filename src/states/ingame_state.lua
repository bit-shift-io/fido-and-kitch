local Lives = require('src.player.lives')
local GameHud = require('src.ui.game_hud')
local AutoCamera = require('src.camera')
local EventBus = require('src.utils.event_bus')
local DebugOverlay = require('src.ui.debug_overlay')
local SpriteOutlineOverlay = require('src.ui.sprite_outline_overlay')
local BaseState = require('src.states.base_state')
local Log = require('src.utils.log')
local Diorama = require('src.diorama')

local InGameState = Class{__includes = BaseState}

local GAME_OVER_ZOOM_DELAY = 0.6

function InGameState:enter()
    Log.debug('ingame enter')
end

function InGameState:load(props)
    if profile then
        profile.start()
    end

    -- Clear NPC registry before loading new map to prevent accumulation across tests
    local NPCRegistry = require('src.npc.npc_registry')
    NPCRegistry.clear()

    self.currentMap = props.map or 'res/map/sandbox.tmx'
    Log.debug('loading map: ' .. self.currentMap)

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
        -- keep a gutter of void around the map at the zoom-out limit so the
        -- diorama frame always has room to show (16 world px = half a tile)
        padding = 16,
    }
    self.gameOverTimer = nil

    self.lives = Lives.defaultCount()
    local ingame = self
    self.gameHud = GameHud{
        getLives=function() return ingame.lives end,
        getCoins=function() return ingame.coinsCollected end,
        getTotal=function() return ingame.totalCoins end,
        getCameraMode=function() return ingame.camera:getMode() end,
    }

    -- Debug overlay
    self.debugOverlay = DebugOverlay:new()
    -- F3 sprite-outline debug overlay
    self.spriteOverlay = SpriteOutlineOverlay:new()

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

    -- Make players globally accessible for NPC follow system
    _G.players = self.players

    -- Count total cages in level
    local cages = map:getEntitiesByType('cage')
    self.totalCages = #cages
    self.unlockedCages = 0
    Log.debug('Level has ' .. self.totalCages .. ' cages')

    -- Set cage counts on each cage entity
    for _, cage in ipairs(cages) do
        cage.totalCages = self.totalCages
        cage.unlockedCount = 0
    end

    -- Listen for cage unlock events
    self.cageUnlockedHandler = EventBus.on('cage_unlocked', utils.bindSelf(InGameState.onCageUnlocked, self))

    -- Count total coins in level and listen for collection
    self.totalCoins = #map:getEntitiesByType('coin')
    self.coinsCollected = 0
    self.coinCollectedHandler = EventBus.on('coin_collected', utils.bindSelf(InGameState.onCoinCollected, self))

    -- Listen for player deaths via EventBus
    EventBus.on('player_died', utils.bindSelf(InGameState.onPlayerDied, self))

    Log.debug('map loaded: ' .. self.currentMap .. ' (' .. #self.players .. ' players, '
        .. self.totalCages .. ' cages, ' .. self.totalCoins .. ' coins)')

    if profile then
        profile.stop()
        print('love.load profile:')
        print(profile.report(10))
    end
end

function InGameState:onCageUnlocked(data)
    self.unlockedCages = self.unlockedCages + 1
    Log.debug('Cage unlocked! Total: ' .. self.totalCages .. ', Unlocked: ' .. self.unlockedCages)
    
    if self.unlockedCages >= self.totalCages then
        Log.debug('All cages unlocked! Emitting all_cages_unlocked event')
        EventBus.emit('all_cages_unlocked', {totalCages = self.totalCages})
    end
end

function InGameState:onCoinCollected(data)
    self.coinsCollected = self.coinsCollected + 1
end

function InGameState:onPlayerDied(data)
    local result = Lives.applyDeath(self.lives)
    self.lives = result.lives

    if result.outcome == 'gameover' then
        self:onGameOver()
    else
        data.player:respawn()
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
    EventBus.clear()
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

    self.gameHud:update(dt)

    for i = 1, 4 do
        if inputManager:wasPressed(i, 'start') then
            local game = self.entity
            game:setGameState('MenuState')
        end
    end
end

function InGameState:draw()
    local tx, ty, sx, sy = self.camera:getDrawParams()
    local mapW, mapH = map:getPixelSize()

    -- Diorama layering: void strips -> parallax bg (scissored to the world
    -- rect) -> world tiles -> frame -> entities
    Diorama.drawVoid(tx, ty, sx, sy, mapW, mapH)
    map:draw2(tx, ty, sx, sy)
    Diorama.drawFrame(tx, ty, sx, sy, mapW, mapH)
    map:drawEntities(tx, ty, sx, sy)

    -- screen-space speech bubbles (follow the entity through pan/zoom, but the
    -- text stays readable at any zoom) -- drawn after entities, before the HUD
    for _, story in ipairs(map:getEntitiesByType('story')) do
        story:drawBubbleScreen(tx, ty, sx, sy)
    end

    -- Debug overlay (hitboxes, ladders, kill zones, safe positions, etc.)
    if conf.drawphysics and self.debugOverlay then
        self.debugOverlay.enabled = true
        local targets = self:collectPlayerTargets()
        local cameraFramingBounds = self.camera:computeTargetView(targets)
        self.debugOverlay:draw(world, map, self.players, tx, ty, sx, sy, cameraFramingBounds)
    else
        self.debugOverlay.enabled = false
    end

    -- F3: sprite outlines (drawn after entities, on top of their art)
    if conf.draw_sprite_outlines and self.spriteOverlay then
        self.spriteOverlay.enabled = true
        self.spriteOverlay:draw(map, self.players, tx, ty, sx, sy)
    else
        self.spriteOverlay.enabled = false
    end

    self.gameHud:draw()
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

local BACK_BUTTONS = {back = true, select = true, guide = true}

function InGameState:gamepadpressed(joystick, button)
    if BACK_BUTTONS[button] then
        self.camera:toggleOverview()
    end
end

return InGameState