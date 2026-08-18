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

function utils.instanceOf(subject, super)
	super = tostring(super)
	local mt = getmetatable(subject)

	while true do
		if mt == nil then return false end
		if tostring(mt) == super then return true end

		mt = getmetatable(mt)
	end	
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

-- Wraps `fn` so it always runs as newSelf:fn(...), discarding whatever the
-- caller invoked the wrapper with as an implicit leading self. Only correct
-- when the call site genuinely invokes the wrapper as a colon/method call
-- passing its own self first -- utils.proxyClass below is the one real case:
-- a proxied method is called as stateMachine:someMethod(...), and
-- stateMachine itself is the leading arg that needs discarding and
-- replacing with the real target (e.g. the FSM's current state).
--
-- Do NOT reach for this for plain callback props -- Collider's enter/
-- postSolve (invoked self.enterFunc(other), a plain call), Timeline/Flash's
-- finish/onComplete (invoked with no args at all), Signal-based events
-- (invoked signal:emit(...) with whatever args the emitter chose). Those
-- callbacks have no leading self to discard, so this silently eats their
-- first real argument. Use utils.bindSelf for those instead. (Previously
-- named utils.forwardFunc -- several entity callback props were mixed up
-- with utils.func this way, harmlessly only because nothing yet read the
-- dropped argument.)
function utils.dropCallerSelf(fn, newSelf)
   return function(oldSelf, ...)
      local function __NULL__() end
      return (fn or __NULL__)(newSelf, ...)
  end
end

-- Wraps `fn` so calling wrapper(...) calls newSelf:fn(...) -- the wrapper
-- itself takes no incoming self, and every argument it's called with is
-- forwarded straight through after newSelf. This is the right choice for
-- plain callback props: Collider's enter/postSolve, Timeline/Flash's
-- finish/onComplete, Signal-based events -- see utils.dropCallerSelf above
-- for why those specifically need this one, not that one. (Previously
-- named utils.func.)
function utils.bindSelf(fn, newSelf)
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
   
   -- If 'to' is a function, call it once before setting metatable to avoid recursion
   local initialForwardTo = to
   if type(to) == 'function' then
      initialForwardTo = to(from)
   end
   
setmetatable(from, {__index = function(_, func)
          -- Check both metatable directly and its __index (class table for hump.class)
          local mtIndex = mt and mt.__index
          local hasMethod = mt and (mt[func] or (mtIndex and (type(mtIndex) == 'table' and mtIndex[func] or type(mtIndex) == 'function' and mtIndex(from, func))))
          if hasMethod then
             return mt[func] or (mtIndex and type(mtIndex) == 'table' and mtIndex[func]) or (mtIndex and type(mtIndex) == 'function' and mtIndex(from, func))
          end

         local forwardTo = to
         if type(to) == 'function' then
            -- Use rawget to avoid triggering this __index again
            forwardTo = rawget(from, 'currentState')
            if forwardTo == nil then
               forwardTo = initialForwardTo
            end
         end

         if forwardTo and type(forwardTo[func]) == 'function' then
            return utils.dropCallerSelf(forwardTo[func], forwardTo)
         else
            return forwardTo and forwardTo[func]
         end
   end})
end

return utils