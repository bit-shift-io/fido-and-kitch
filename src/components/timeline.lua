-- Timeline is the base class for controlling animation and timing and firing events etc

local Timeline = Class{}

function Timeline:init(props)
    self.playing = false
    if (props.playing) then
        self.playing = props.playing
    end

    self.tween = Tween.new(props.duration, {time=0.0}, {time=1.0}, props.easing)
    self.duration = props.duration
    self.speed = 1
    self.isReverse = false
    self.loop = false
    if (props.loop) then
        self.loop = props.loop
    end

    self.bounce = false
    if (props.bounce) then
        self.bounce = props.bounce
    end

    self.hold = props.hold or 0
    self._holdTimer = 0
    self._bounceCount = 0

    self.events = {} -- pairs of time/Func's for firing off events
    self.finishSignal = Signal{}

    if (props.finish) then
        self.finishSignal:connect(props.finish)
    end
end

function Timeline:update(dt)
    if self.playing == false then
 		return
 	end
    
    -- Defensive check for dt being a table
    if type(dt) ~= 'number' then
        Log.error("Timeline:update received non-number dt:", type(dt), dt)
        dt = 1/60  -- fallback
    end

    -- Hold at bounce endpoints: pause before reversing
    if self._holdTimer > 0 then
        self._holdTimer = self._holdTimer - dt
        if self._holdTimer <= 0 then
            self._holdTimer = 0
            self.isReverse = not self.isReverse
        end
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
    local overflow = (self.tween.clock + dt) - self.tween.duration
    self.tween:update(dt)
    local endClock = self.tween.clock
    local etp = self:timePercent()

    -- Check for bounce at end (forward) or start (reverse)
    local bounced = false
    if dt > 0 and endClock == self.tween.duration then
        if self.bounce and not self.isReverse then
            -- Hit end going forward, bounce to reverse
            self.tween:set(self.tween.duration)
            self._bounceCount = self._bounceCount + 1
            if self.hold > 0 then
                self._holdTimer = self.hold
            else
                self.isReverse = true
            end
            bounced = true
        elseif not self.loop then
            self.playing = false
        end
    end

    if dt < 0 and endClock == 0 then
        if self.bounce and self.isReverse then
            -- Hit start going reverse
            if self.loop then
                -- Loop mode: bounce back to forward
                self.tween:reset()
                self._bounceCount = self._bounceCount + 1
                if self.hold > 0 then
                    self._holdTimer = self.hold
                else
                    self.isReverse = false
                end
                bounced = true
            else
                -- Non-loop mode: completed one full bounce cycle (forward->reverse->forward), stop
                self.playing = false
            end
        elseif not self.loop then
            self.playing = false
        end
    end

    self:fireEvents(stp, etp)

    if dt > 0 and endClock == self.tween.duration then
        if self.loop and not bounced then
            self.tween:reset()
            self:progress(overflow, supressEvents)
        end
    end

    if dt < 0 and endClock == 0 then
        if self.loop and not bounced then
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
end

-- play forward from the start
function Timeline:playForward()
    self:reset()
    self:play()
end

-- play in reverse from the end
function Timeline:playReverse()
    self:resetReverse()
    self:play()
end

-- flip direction from wherever the playhead currently is (no snap), and
-- make sure playback is running; this is the drawbridge's mid-close
-- reverse-in-place interrupt
function Timeline:reverseFromCurrent()
    self:reverse()
    self:play()
end

function Timeline:getDirection()
    if self.isReverse then
        return 'reverse'
    end
    return 'forward'
end

function Timeline:setDirection(direction)
    self.isReverse = (direction == 'reverse')
end

function Timeline:setSpeed(speed)
    self.speed = speed
end

function Timeline:getSpeed()
    return self.speed
end

function Timeline:isPlaying()
    return self.playing
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

function Timeline:play()
    self.playing = true
end

function Timeline:stop()
    self.playing = false
end

return Timeline