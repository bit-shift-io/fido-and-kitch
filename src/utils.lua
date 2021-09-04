local utils = {}


-- function used for both
function utils.set_funcs(mainobject, subobject)
   -- this function assigns functions of a subobject to a primary object
   --[[
      mainobject: the table to which to assign the functions
      subobject: the table whose functions to assign
      no output
   --]]
   for k, v in pairs(subobject.__index) do
      if k ~= '__gc' and k ~= '__eq' and k ~= '__index'
	 and k ~= '__tostring' and k ~= 'destroy' and k ~= 'type'
         and k ~= 'typeOf'and k ~= 'getUserData' and k ~= 'setUserData' then
	 mainobject[k] = function(mainobject, ...)
	    return v(subobject, ...)
	 end
      end
   end
end

utils.COLLIDER_TYPES = {
   CIRCLE = "Circle",
   CIRC = "Circle",
   RECTANGLE = "Rectangle",
   RECT = "Rectangle",
   POLYGON = "Polygon",
   POLY = "Polygon",
   EDGE = 'Edge',
   CHAIN = 'Chain'
}


function utils.instanceOf(subject, super)
	super = tostring(super)
	local mt = getmetatable(subject)

	while true do
		if mt == nil then return false end
		if tostring(mt) == super then return true end

		mt = getmetatable(mt)
	end	
end


function utils.tableFind(tab,el)
   for index, value in pairs(tab) do
      if value == el then
         return index
      end
   end
   return nil
end


-- https://stackoverflow.com/questions/9268954/lua-pass-context-into-loadstring
function utils.loadCode(code, environment)
   setmetatable(environment, { __index = _G }) -- hook up global access

   if setfenv and loadstring then
       local f = assert(loadstring(code))
       setfenv(f, environment)
       return f
   else
       return assert(load(code, nil, "t", environment))
   end
end

-- TODO: now there is confusion around when to use forwardFunc or
-- func! 

-- forward a function call from oldSelf:fn(...) to newSelf:fn(...)
function utils.forwardFunc(fn, newSelf)
   return function(oldSelf, ...)
      local function __NULL__() end
      return (fn or __NULL__)(newSelf, ...)
  end
end

-- make a function fn(...) call newSelf:fn(...)
function utils.func(fn, newSelf)
   return function(...)
      local function __NULL__() end
      return (fn or __NULL__)(newSelf, ...)
  end
end

-- forward any undefined functions called on 'from' to 'to'
-- if 'to' is a function, it acts as a dynamic proxy, incase you are changing what class you are proxying to
-- on the fly. For example, a state machine proxies to the current state
function utils.proxyClass(from, to)
   local mt = getmetatable(from)
   setmetatable(from, {__index = function(_, func)
         if mt and mt[func] then
            return mt[func]
         end

         local forwardTo = to
         if type(to) == 'function' then
            forwardTo = to(from)
         end

         if type(forwardTo[func]) == 'function' then
            return utils.forwardFunc(forwardTo[func], forwardTo)
         else
            return forwardTo[func]
         end
   end})
end


return utils