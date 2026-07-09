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
        finish=function()
            self:finish()
            if finish then
                finish()
            end
        end
    })

    -- do we need an option to do this?
    if self.sprite then
        local pos = self.path:getPositionV(0)
        self.sprite:setPositionV(pos)
    end
end


function PathFollow:update(dt)
    -- incase the user wants to manually fudge frame numbers
	if self.timeline.playing == false then
		return;
	end
	self.timeline:update(dt)

    if self.sprite then
        local pos = self.path:getPositionV(self.timeline:timePercent())
        pos = pos + self.offset
        self.sprite:setPositionV(pos)
    end

    if self.collider then
        local pos = self.path:getPositionV(self.timeline:timePercent())
        pos = pos + self.offset
        self.collider:setPositionV(pos)
    end
end


function PathFollow:getPositionV()
    local pos = self.path:getPositionV(self.timeline:timePercent())
    return pos
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