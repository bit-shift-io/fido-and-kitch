bump = require('lib.bump.bump')

local World   = {}
World.__index = World

function World:new(...)
   --local w = {}
   --setmetatable(w, self)
   --w._world = bump.newWorld(32)
   self.type = 'bump'
   self._world = bump.newWorld(32)

   self.colliders = {}
   self.queryRects = {}
   --utils.set_funcs(w, w._world)
   return self
end


function World:draw()
   for _, c in pairs(self.colliders) do
      c:worldDraw()
   end

   local r, g, b, a = love.graphics.getColor()
   love.graphics.setColor(1, 0, 0, 1)
   for _, c in pairs(self.queryRects) do
		love.graphics.rectangle('line', c.x, c.y, c.width, c.height)
	end
   love.graphics.setColor(r, g, b, 1)
   self.queryRects = {}
end


function World:update(dt)
   for _, c in pairs(self.colliders) do
      c:worldUpdate(dt)
   end
end


function World:newCollider(collider_type, shape_arguments, table_to_use)
   local o = table_to_use or {}
   setmetatable(o, Collider)

   if collider_type == 'circle' then
      local x, y, r = unpack(shape_arguments)
      o.x = x
      o.y = y
      o.width = r
      o.height = r
   elseif collider_type == 'rectangle' then
      local x, y, w, h = unpack(shape_arguments)
      o.x = x
      o.y = y
      o.width = w
      o.height = h
   else
      local u = unpack(shape_arguments)
      o.x = 0
      o.y = 0
      o.width = 32
      o.height = 32
   end

   o.collider_type = 'rectangle'

   local halfWidth = o.width / 2
   local halfHeight = o.height / 2
   o.x = o.x - halfWidth
   o.y = o.y - halfHeight
   self._world:add(o, o.x, o.y, o.width, o.height)

   o._world = self
   self.colliders[o] = o
   return o
end

function World.colFilter(a, b)
	-- allow a nd b to go through each other
	if (a.sensor or b.sensor) then
		return 'cross'
	end

	-- emulate box2d, if in the collision group ignore the collision
	if (a.groupIndex == b.groupIndex) then
		return nil
	end

   -- kinematic means driven by where velocity we can walk through walls
   if (a.bodyType == 'kinematic') then
      return 'cross'
   end

	return 'slide'
end

function World.queryColFilter(a, b)
	return 'cross'
end

function World:queryRectangleArea(x1, y1, x2, y2)
   -- create a temporary rect and do a collision query
   local width = x2 - x1
   local height = y2 - y1
   local item = {id='temp'}
   local halfHeight = height / 2
   local halfWidth = width / 2
   
   self._world:add(item, x1, y1, width, height)
   local actualX, actualY, cols, len = self._world:check(item, x1, y1, self.queryColFilter)
   self._world:remove(item)

   table.insert(self.queryRects, {x=x1, y=y1, width=width, height=height})

   for i,v in ipairs(cols) do
		v.entity = v.other.entity
	end

   return cols
end


function World:queryBounds(bounds)
   return self:queryRectangleArea(bounds.left, bounds.top, bounds.right, bounds.bottom)
end


return World