local Ladder = Class{__includes = Entity}

function Ladder:init(object)
	Entity.init(self)
	self.object = object
	self.name = object.name
	self.type = 'ladder'
	self.isLadder = true
	self.rect = Rect(object)
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments=self.rect:colliderShapeArgs(), 
		body_type='static',
		sensor=true,
		position=self.rect:centre(),
		--enter=utils.forwardFunc(self.enter, self),
		--exit=utils.forwardFunc(self.exit, self),
		entity=self
	})
	self:createSprites()

	-- test resizing
	--self:resizeTileHeight(self:tileHeight() + 2, 'top')
end

function Ladder:tileHeight()
	return self.rect.height / map.tileheight
end

-- if side is not supplied, top is the default
function Ladder:resizeTileHeight(newTileHeight, side)
	print('resize height to '..newTileHeight)

	newHeight = (newTileHeight * map.tileheight)
	heightDelta = newHeight - self.rect.height
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
		--enter=utils.forwardFunc(self.enter, self),
		--exit=utils.forwardFunc(self.exit, self),
		entity=self
	})

	self:createSprites()
end

function Ladder:grow(tileHeight, side) 
	self:resizeTileHeight(self:tileHeight() + tileHeight, side)
end

function Ladder:createSprites()
	tileHeight = self:tileHeight()

	-- TODO: handle resizing better
	if self.sprites then
		for _, sprite in pairs(self.sprites) do
			self:removeComponent(sprite)
		end
	end

	self.sprites = {}
	for i = 0, (tileHeight - 1), 1 do
		rect = Rect{x=self.rect.x, y=self.rect.y + (i * map.tileheight), width=map.tilewidth, height=map.tileheight}
		sprite = self:addComponent(Sprite{
			image='res/img/ladder.png',
			frames=4,
			duration=1.0,
			loop=false,
			position=rect:centre(),
			shape_arguments=rect:colliderShapeArgs(),
			--finish=utils.forwardFunc(ExitDoor.animFinished, self)
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