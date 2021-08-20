local StateMachine = Class{}

function StateMachine:init(props)
	self.type = 'state_machine'

    self.states = props.states or {}
    self.entity = props.entity

    for n, s in pairs(props.stateClasses) do
        local instance = s{props}
        instance.fsm = self
        instance.entity = props.entity
        self.states[n] = instance
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

    if (prevState ~= nil and prevState.exit ~= nil) then
      prevState:exit();
    end

    if (nextState ~= nil and nextState.enter ~= nil) then
      nextState:enter();
    end

    self.currentState = nextState;
end

function StateMachine:update(dt)
    if (self.currentState.update ~= nil) then
        self.currentState:update(dt)
    end
end

return StateMachine