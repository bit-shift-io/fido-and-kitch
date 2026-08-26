-- Path follow component
-- follow a polyline

local PathFollow = Class{}

function PathFollow:init(props)
	self.type = 'path_follow'
    self.path = props.path
    self.sprite = props.sprite
    self.collider = props.collider
    self.offset = props.offset or Vector(0, 0)

    if self.collider then
        self.previousGravityScale = self.collider.gravityScale
        self.previousVelocityX, self.previousVelocityY = self.collider:getLinearVelocity()
        self.collider:setGravityScale(0)
        self.collider:setLinearVelocity(0, 0)
    end

    local speed = props.speed
    local duration = self.path.length / speed
    local finish = props.finish
    self.timeline = Timeline({
        duration=duration,
        easing=props.easing,
        finish=function()
            self:finish()
            if finish then
                finish()
            end
        end
    })

    self._lastPos = nil
    self._velocity = Vector(0, 0)

    if self.sprite then
        local pos = self.path:getPositionV(0)
        self.sprite:setPositionV(pos)
        self._lastPos = pos
    end
end


function PathFollow:update(dt)
	if self.timeline.playing == false then
		return
	end
	self.timeline:update(dt)

	local distance = self.timeline:timePercent() * self.path.length
	local pos = self.path:getPositionV(distance)
	pos = pos + self.offset

	if self.sprite then
		self.sprite:setPositionV(pos)
	end

	if self.collider then
		self.collider:setPositionV(pos)
	end

	if self._lastPos then
		self._velocity = (pos - self._lastPos) / dt
	end
	self._lastPos = pos
end


function PathFollow:getPositionV()
    local distance = self.timeline:timePercent() * self.path.length
    local pos = self.path:getPositionV(distance)
    return pos
end

function PathFollow:getVelocity()
    return self._velocity:clone()
end

function PathFollow:finish()
    if self.finished then
        return
    end

    self.finished = true
    if self.collider then
        self.collider:setGravityScale(self.previousGravityScale or 1)
        self.collider:setLinearVelocity(self.previousVelocityX or 0, self.previousVelocityY or 0)
    end
end

function PathFollow:destroy()
    self:finish()
end


function PathFollow:draw()
    self.path:draw()
end


return PathFollow