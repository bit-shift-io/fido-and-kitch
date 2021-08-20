local StateMachine = Class{}

function StateMachine:init(props)
	self.type = 'state_machine'

    self.states = props.states or {}
    self.entity = props.entity

    -- stateClasses are classes we want to create instances of
    if (props.stateClasses) then
        for n, s in pairs(props.stateClasses) do
            local instance = s{props}
            instance.fsm = self
            instance.entity = props.entity
            self.states[n] = instance
        end
    end
    
    self.currentState = nil
    if (props.currentState) then
        self:setState(props.currentState)
    end
end

function StateMachine:addState(state)
    self.states[state.name] = state;
end

function StateMachine:tryTransition(name)
    local s = self.states[name];
    if (s:canTransition()) then
        self:setState(name)
    end
end

function StateMachine:setState(name)
    local prevState = self.currentState;
    local nextState = self.states[name];

    if (prevState == nextState) then
        return
    end

    if (prevState ~= nil and prevState.exit ~= nil) then
      prevState:exit();
    end

    if (nextState ~= nil and nextState.enter ~= nil) then
      nextState:enter();
    end

    self.currentState = nextState;

    -- special case for Sprites - should be replaced with a onChangeState callback?
    if (prevState ~= nil and prevState.getPositionV ~= nil) then
        self:setPositionV(prevState:getPositionV())
    end
end

function StateMachine:update(dt)
    if (self.currentState.update ~= nil) then
        self.currentState:update(dt)
    end
end

function StateMachine:draw()
    if (self.currentState.draw ~= nil) then
        self.currentState:draw()
    end
end

-- Ideally I want say: fsm:doIt()
-- to forward to fsm.currentState:doIt()
-- to save the code below setPositionV
-- that way the fsm can clock itself as any component
--[[
function StateMachine:__index(table, key, x, y, z)
    local mt = getmetatable(self)
    local entry = mt[table]
    if (entry == nil) then
        mt = getmetatable(self.currentState)
        entry = mt[table]
    end
    return entry
end
]]--

function StateMachine:setPositionV(pos)
    if (self.currentState.setPositionV ~= nil) then
	    self.currentState:setPositionV(pos)
    end
end

return StateMachine