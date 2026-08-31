-- src/components/speed_streak.lua — mesh ribbon trail for fast airborne movement
-- Attaches to a player entity and emits a continuous mesh ribbon trail while airborne.
local Class = require('lib.hump.class')
local MeshRibbonEmitter = require('src.emitters.mesh_ribbon_emitter')
local Log = require('src.utils.log')

local SpeedStreak = Class{}

function SpeedStreak:init(props)
    self.entity = props.entity
    self.enabled = false

    self.emitter = MeshRibbonEmitter.new({
        maxSegments = 80,
        width = 32,
        lifetime = 0.98,
        colorStart = {1, 1, 1, 1},
        colorEnd = {1, 1, 1, 0},
        debugAlphaColor = false,
        texture = 'res/img/fx/fx_speed_streak.png',
        textureScaleV = 1.0,
        textureScroll = 0,
        textureRotation = 90,
        minSpeed = 0,
        fadeInTime = 0.12,   -- 12% lifetime fade in
        fadeOutTime = 0.3,   -- 30% lifetime fade out
        widthVerticalReduction = 0.2,
    })
end

function SpeedStreak:enable()
    self.enabled = true
    Log.debug("SpeedStreak ENABLED - resetting emitter")
    self.emitter:reset()
end

function SpeedStreak:disable()
    Log.debug("SpeedStreak DISABLED")
    self.enabled = false
end

function SpeedStreak:update(dt)
    local vx, vy = self.entity.collider:getLinearVelocity()
    local PathFollow = require('src.components.path_follow')
    local pathFollow = self.entity:getComponent(PathFollow)
    if pathFollow and pathFollow.getVelocity then
        local pv = pathFollow:getVelocity()
        vx, vy = pv.x, pv.y
    end

    local pos = self.entity.collider:getPositionV()
    
    -- Only add new segments when enabled, but always update existing ones to age them out
    if self.enabled then
        self.emitter:update(dt, pos, {x = vx, y = vy})
    else
        -- Update with zero velocity to age out existing segments
        self.emitter:update(dt, pos, {x = 0, y = 0})
    end
end

function SpeedStreak:draw()
    self.emitter:draw()
end

function SpeedStreak:onAttach()
    -- no-op
end

function SpeedStreak:onDetach()
    -- no-op
end

return SpeedStreak