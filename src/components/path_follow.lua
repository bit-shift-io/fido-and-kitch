-- Path follow component
-- follow a polyline

local PathFollow = Class{}

function PathFollow:init(props)
	self.type = 'path_follow'
    self.path = props.path
    self.sprite = props.sprite

    local speed = props.speed
    local duration = self.path.length / speed
    local finsh = props.finish
    self.timeline = Timeline({
        duration=duration,
        finish=finsh
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
        self.sprite:setPositionV(pos)
    end
end

function PathFollow:getPositionV() 
    return self.path:getPositionV(self.timeline:timePercent())
end

function PathFollow:draw()
    self.path:draw()
end

return PathFollow