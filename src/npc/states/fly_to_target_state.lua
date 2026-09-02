-- src/npc/states/fly_to_target_state.lua
-- Forced state a friendly flying NPC (bird) enters when spawned from a cage
-- with a `target` (see cage.lua): flies a swoop-curve arc from its current
-- position to entity.switchTarget, activates the target's Usable component
-- on arrival exactly as a player using it would, then hands control back to
-- the normal utility system (which picks FollowState, since the cage
-- already called setTarget(user) before this state ever ran).
local Class = require('lib.hump.class')
local Log = require('src.utils.log')
local SwoopCurve = require('src.utils.swoop_curve')

-- How densely the swoop curve is sampled into the polyline handed to Path.
-- Path itself re-samples the polyline into 100 arc-length-uniform samples,
-- so this only needs to be dense enough to capture the curve's shape.
local SAMPLE_COUNT = 24

local FlyToTargetState = Class{}

function FlyToTargetState:enter(prevState)
    local entity = self.entity
    local target = entity.switchTarget

    self.activated = false
    self.pathFollow = nil

    if not target or not target.entity or not target.entity.collider then
        Log.error('FlyToTargetState entered without a resolvable switchTarget; aborting flight')
        entity.forcedState = nil
        entity.flownToTarget = true
        return
    end

    self.target = target

    local startPos = entity.collider:getPositionV()
    local destPos = target.entity.collider:getPositionV()

    local curve = SwoopCurve.generateCurve(
        {x = startPos.x, y = startPos.y},
        {x = destPos.x, y = destPos.y}
    )

    local polyline = {}
    for i = 0, SAMPLE_COUNT do
        local t = i / SAMPLE_COUNT
        local point = SwoopCurve.computeCurvePoint(curve, t)
        table.insert(polyline, {x = point.x, y = point.y})
    end

    local speed = entity.targetFlightSpeed or 150

    self.pathFollow = entity:addComponent(PathFollow{
        collider = entity.collider,
        path = Path{polyline = polyline},
        speed = speed,
        finish = function() self:onArrive() end,
    })
    -- PathFollow builds its Timeline paused (mirrors JumpPad:use, which
    -- explicitly plays the player's pathFollow.timeline) -- start it here.
    self.pathFollow.timeline:play()
end

function FlyToTargetState:onArrive()
    if self.activated then
        return
    end
    self.activated = true

    local entity = self.entity
    local target = self.target

    if target and target.entity then
        local usable = target.entity:getComponent(Usable)
        if usable and usable:canUse(entity) then
            usable:use(entity)
        end
    end

    entity.forcedState = nil
    entity.flownToTarget = true
end

function FlyToTargetState:exit(prevState)
    local entity = self.entity
    if self.pathFollow then
        entity:removeComponent(self.pathFollow)
        self.pathFollow = nil
    end
end

return FlyToTargetState
