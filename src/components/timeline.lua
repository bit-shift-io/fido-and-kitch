-- Timeline is the base class for controlling animation and timing and firing events etc

local Timeline = Class{}

function Timeline:init(props)
    self.playing = false
    if (props.playing) then
        self.playing = props.playing
    end

    self.tween = Tween.new(props.duration, {time=0.0}, {time=1.0})
    self.duration = props.duration
    self.speed = 1
    self.isReverse = false
    self.loop = false
    if (props.loop) then
        self.loop = props.loop
    end

    self.events = {} -- pairs of time/Func's for firing off events
    self.finishSignal = Signal{}

    --[[
    if (props.start) then
        table.insert(self.events, {
            time=0.0,
            fn=props.start 
        })
    end
    ]]--

    --[[
    if (props.finish) then
        table.insert(self.events, {
            time=1.0,
            fn=props.finish 
        })
    end
    ]]--

    if (props.finish) then
        self.finishSignal:connect(props.finish)
    end
end

--[[
-- clear existing finish func and set new finish event
function Timeline:setFinishFunc(fn)
    self.finishEvents = {}
    if (fn) then
        table.insert(self.finishEvents, fn)
    end
end
]]--

function Timeline:update(dt)
    if self.playing == false then
		return
	end

    local speed = self.speed
    if (self.isReverse) then
        speed = -speed
    end

    self:progress(dt * speed)

    -- TODO: set playing = false if start/end reached
end


-- fire any events we passed along the way between startClock and endClock
function Timeline:fireEvents(startPercent, endPercent)
    local forward = endPercent > startPercent

    for _, v in pairs(self.events) do
        if (forward) then
            if (startPercent < v.time and endPercent >= v.time) then
                v.fn()
            end
        else
            if (startPercent <= v.time and endPercent > v.time) then
                v.fn()
            end
        end
    end

    -- special handling for 'finish' events which can occur at at start or end of the animation
    if (forward) then
        if endPercent == 1.0 then
            self.finishSignal:emit()
        end
    else
        if endPercent == 0.0 then
            self.finishSignal:emit()
        end
    end
end


function Timeline:progress(dt, supressEvents)
    local stp = self:timePercent()
    local startClock = self.tween.clock
    local overflow = (self.tween.clock + dt) - self.tween.duration
    self.tween:update(dt)
    local endClock = self.tween.clock
    local etp = self:timePercent()

    if dt > 0 and endClock == self.tween.duration then
        if not self.loop then
            self.playing = false
        end
    end

    if dt < 0 and endClock == 0 then
        if not self.loop then
            self.playing = false
        end
    end

    self:fireEvents(stp, etp)

    if dt > 0 and endClock == self.tween.duration then
        if self.loop then
            self.tween:reset()
            self:progress(overflow, supressEvents)
        end
    end

    if dt < 0 and endClock == 0 then
        if self.loop then
            self.tween:set(self.tween.duration)
            self:progress(overflow, supressEvents)
        end
    end
end

-- move playhead to start and set for playing in the forward direction
function Timeline:reset()
    self.isReverse = false
    self.tween:reset()
end

-- move playhead to end and setup for playing in reverse
function Timeline:resetReverse()
    self.isReverse = true
    self.tween:set(self.tween.duration)
end

function Timeline:reverse()
    self.isReverse = not self.isReverse
    --self.tween = Tween.new(self.tween.duration, {time=1.0}, {time=0.0})
end

-- Given a set of frames 
-- compute which frame is current
function Timeline:getFrameIndex(frameCount)
    local percent = self.tween.subject.time
    local idx = 1 + ((frameCount - 1) * math.max(math.min(1, percent), 0))
    assert(idx >= 1, 'index out of bounds')
    assert(idx <= frameCount, 'index out of bounds')
    return math.floor(idx)
end

-- get time as a percentage
function Timeline:timePercent()
    return self.tween.subject.time
end

-- get time as a duration
function Timeline:timeDuration()
    return self.tween.clock
end

function Timeline:play()
    self.playing = true
end

function Timeline:stop()
    self.playing = false
end

return Timeline