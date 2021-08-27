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

    if (props.start) then
        table.insert(self.events, {
            time=0.0,
            fn=props.start 
        })
    end

    if (props.finish) then
        table.insert(self.events, {
            time=1.0,
            fn=props.finish 
        })
    end
end

function Timeline:setFinishFunc(fn)
    -- change the fn
    -- TODO: should we simply add a new finish event?
    -- I"m not happy with this yet... needs more thought
    -- we might want multiple finish events!
    for i, v in pairs(self.events) do
        if (v.time == 1.0) then
            v.fn = fn
            return
        end
    end

    table.insert(self.events, {
        time=1.0,
        fn=fn 
    })
end

function Timeline:update(dt)
    if self.playing == false then
		return
	end

    local speed = self.speed
    if (self.isReverse) then
        speed = -speed
    end

    self:progress(dt * speed)
end


-- fire any events we passed along the way between startClock and endClock
function Timeline:fireEvents(startPercent, endPercent)
    for _, v in pairs(self.events) do
        if (startPercent < v.time and endPercent >= v.time) then
            v.fn:call()
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

    self:fireEvents(stp, etp)

    if self.tween.clock == self.tween.duration then
        if self.loop then
            self.tween:reset()
            self:progress(overflow, supressEvents)
        end
    end
end

function Timeline:reset()
    self.tween:reset()
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