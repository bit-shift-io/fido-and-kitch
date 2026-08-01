local Log = require('src.utils.log')

local Ladder = Class{__includes = Entity}

function Ladder:init(object, map)
	Entity.init(self, object, 'ladder')
	self.isLadder = true
	self.map = map
	self.rect = Rect(object)
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments=self.rect:colliderShapeArgs(), 
		body_type='static',
		sensor=true,
		position=self.rect:centre(),
		--enter=utils.bindSelf(self.enter, self),
		--exit=utils.bindSelf(self.exit, self),
		entity=self
	})
	self:createSprites()

	-- test resizing
	--self:resizeTileHeight(self:tileHeight() + 2, 'top')
end

function Ladder:tileHeight()
	return self.rect.height / self.map.tileheight
end

-- if side is not supplied, top is the default
function Ladder:resizeTileHeight(newTileHeight, side)
	Log.debug('resize height to '..newTileHeight)

	local newHeight = (newTileHeight * self.map.tileheight)
	local heightDelta = newHeight - self.rect.height
	self.rect.height = newHeight
	if side == nil or side == 'top' then -- move the top up
		self.rect.y = self.rect.y - heightDelta
	end

	-- destroy the old physics
	self:removeComponent(self.collider)
	self.collider:destroy()

	-- create the new
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments=self.rect:colliderShapeArgs(), 
		body_type='static',
		sensor=true,
		position=self.rect:centre(),
		--enter=utils.bindSelf(self.enter, self),
		--exit=utils.bindSelf(self.exit, self),
		entity=self
	})

	self:createSprites()
end

function Ladder:grow(tileHeight, side) 
	self:resizeTileHeight(self:tileHeight() + tileHeight, side)
end

function Ladder:createSprites()
	local tileHeight = self:tileHeight()

	-- TODO: handle resizing better
	if self.sprites then
		for _, sprite in pairs(self.sprites) do
			self:removeComponent(sprite)
		end
	end

	self.sprites = {}
	for i = 0, (tileHeight - 1), 1 do
		local rect = Rect{x=self.rect.x, y=self.rect.y + (i * self.map.tileheight), width=self.map.tilewidth, height=self.map.tileheight}
		local sprite = self:addComponent(Sprite{
			image='res/img/ladder.png',
			frames=4,
			duration=1.0,
			loop=false,
			position=rect:centre(),
			shape_arguments=rect:colliderShapeArgs(),
			--finish=utils.bindSelf(ExitDoor.animFinished, self)
		})
		--sprite.timeline:resetReverse()
		sprite.timeline:play()
		table.insert(self.sprites, sprite)
    end
end

--[[
function Ladder:enter(user)
	user.entity.ladder = self
end

function Ladder:exit(user)
	if user.entity.ladder == self then
		user.entity.ladder = null
	end
end
]]--

function Ladder:switch(switch, user)
	if (switch.state == 'on') then
		self.object:exec('switchOn', self)
	end
end


return Ladder