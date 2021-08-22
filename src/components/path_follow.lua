-- Path follow component
-- follow a polyline

local PathFollow = Class{}

function PathFollow:init(props)
	self.type = 'path_follow'
    self.path = props.path
    self.sprite = props.sprite
    self.currentTime = 0
    self.speed = props.speed or 30
    self.t = 0
    self.finishFunc = props.finish

    self.playing = false
	if props.playing ~= nil then
		self.playing = props.playing
	end

    -- do we need an option to do this?
    if self.sprite then
        local pos = self.path:getPositionV(0)
        self.sprite:setPositionV(pos)
    end
end

function PathFollow:update(dt)
    if self.playing == false then
		return
	end

    local tPrev = self.t
    self.currentTime = self.currentTime + dt
    local dist = (self.speed * self.currentTime) / self.path.length
    self.t = dist

    if self.t >= 1 and tPrev < 1 and self.finishFunc then
        self.finishFunc:call()
    end

    if self.sprite then
        local pos = self.path:getPositionV(dist)
        self.sprite:setPositionV(pos)
    end
end

function PathFollow:getPositionV() 
    return self.path:getPositionV(self.t)
end

function PathFollow:setPlaying(playing)
    self.playing = playing
end

function PathFollow:draw()
    self.path:draw()
end

return PathFollow