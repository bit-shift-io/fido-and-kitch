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
            instance.name = n
            self.states[n] = instance
        end
    end
    
    if (props.currentState) then
        self:setState(props.currentState)
    end

    -- forward any undefined functions to the currentState
    utils.proxyClass(self, function(s)
        return s.currentState
    end)
end

function StateMachine:tryTransition(name)
    local s = self.states[name];
    if (s:canTransition()) then
        self:setState(name)
        return true
    end

    return false
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
      nextState:enter(prevState);
    end

    self.currentState = nextState;

    -- special case for Sprites - should be replaced with a onChangeState callback?
    if (prevState ~= nil and prevState.getPositionV ~= nil) then
        self:setPositionV(prevState:getPositionV())
    end
end

function StateMachine:update(dt)
    if self.currentState and self.currentState.update then
        self.currentState:update(dt)
    end
end


return StateMachine