local Cage = Class{__includes = Entity}

function Cage:init(object)
	Entity.init(self)
	self.type = 'cage'
	local color = object.properties.color
	local position = Vector(object.x + object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/cage.png',
		frames=1,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=shape_arguments,
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments={0, 0, 32, 32},
		body_type='static',
		sensor=true,
		position=position
	})
	
	self:addComponent(Usable{
		entity=self,
		use=utils.forwardFunc(self.use, self),
		requiredItem=string.format('key_%s', color)
	})

	-- spawn the prisoner!
	if object.properties.path == nil then
		print('Cage has no path property setup for the actor to follow when released')
		return
	end

	local pathObj = map:getObjectById(object.properties.path.id)

	local layer = object.layer
	local ok, err = pcall(require, object.properties.actor or 'bird') 
	if not ok then
		print('Entity Error: ' .. err)
	else
		local entity = err(pathObj)
		--entity.mapData = object -- store the map data in the entity
		table.insert(layer.entities, entity)
		self.actor = entity
	end
end

function Cage:use(user)
	print('Cage has been used')
	-- for now just stop drawing the cage, in future we need an animation to play
	self:removeComponent(self.sprite)
	self.actor:trigger()
end

return Cage