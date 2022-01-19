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
   --utils.set_funcs(w, w._world)
   return self
end


function World:draw()
   return nil
end


function World:update(dt)
   for _, c in pairs(self.colliders) do
      c:move(dt)
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

   self._world:add(o, o.x, o.y, o.width, o.height)

   o._world = self
   self.colliders[o] = o
   return o
end


function World:queryRectangleArea(x1, y1, x2, y2)
   local cols = {}
   return cols
end


function World:queryBounds(bounds)
   return self:queryRectangleArea(bounds.left, bounds.top, bounds.right, bounds.bottom)
end


return World