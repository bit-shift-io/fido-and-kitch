-- src/npc/states/fly_to_door_state.lua
-- Forced state a following bird enters once the exit door opens
-- (BirdNPC's exit_door_opened handler sets entity.forcedState/forcedStateParams
-- unconditionally, so this overrides whatever the bird was doing, including a
-- still-in-progress FlyToTargetState). Flies a swoop-curve arc from the
-- bird's current position to the door's position (entity.forcedStateParams),
-- then queues the bird for destruction on arrival -- mirrors
-- fly_to_target_state.lua, the reference implementation for a directed
-- swoop-curve flight, but there is no Usable to activate on arrival.
local Class = require('lib.hump.class')
local Log = require('src.utils.log')
local SwoopCurve = require('src.utils.swoop_curve')

-- How densely the swoop curve is sampled into the polyline handed to Path.
-- Path itself re-samples the polyline into 100 arc-length-uniform samples,
-- so this only needs to be dense enough to capture the curve's shape.
local SAMPLE_COUNT = 24

local FlyToDoorState = Class{}

function FlyToDoorState:enter(prevState)
    local entity = self.entity
    local dest = entity.forcedStateParams

    self.pathFollow = nil

    if not dest or not dest.x or not dest.y then
        Log.error('FlyToDoorState entered without a resolvable destination; aborting flight')
        entity.forcedState = nil
        entity.forcedStateParams = nil
        return
    end

    local startPos = entity.collider:getPositionV()

    local curve = SwoopCurve.generateCurve(
        {x = startPos.x, y = startPos.y},
        {x = dest.x, y = dest.y}
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
    -- PathFollow builds its Timeline paused -- start it here (see
    -- fly_to_target_state.lua's comment on the same gotcha).
    self.pathFollow.timeline:play()
end

function FlyToDoorState:onArrive()
    local entity = self.entity
    entity:queueDestroy()
end

function FlyToDoorState:exit(prevState)
    local entity = self.entity
    if self.pathFollow then
        entity:removeComponent(self.pathFollow)
        self.pathFollow = nil
    end
end

return FlyToDoorState
