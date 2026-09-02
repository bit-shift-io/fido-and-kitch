-- StateMachine:tryTransition must report whether the transition happened.
-- Its only callers (WalkIdleState:update) guard their remaining frame logic
-- with `if fsm:tryTransition(...) then return end` -- a nil return made that
-- guard always false, so after a successful FallState transition the rest of
-- WalkIdleState:update still ran: the walk decision re-ran while already
-- falling, printing a phantom animation switch and writing walk velocity
-- onto the falling body (air-control leak).
require("tests.support.headless_bootstrap")

local StateMachine = require("src.components.state_machine")

local function makeMachine()
	local calls = {}
	local states = {
		A = {
			enter = function()
				table.insert(calls, "A enter")
			end,
			update = function() end,
		},
		B = {
			canTransition = function()
				return true
			end,
			enter = function()
				table.insert(calls, "B enter")
			end,
			update = function() end,
		},
		C = {
			canTransition = function()
				return false
			end,
			update = function() end,
		},
	}
	local fsm = StateMachine({ states = states, entity = {} })
	fsm.currentState = states.A
	return fsm, calls
end

test("tryTransition returns true and switches when canTransition passes", function()
	local fsm, calls = makeMachine()
	assertTrue(fsm:tryTransition("B") == true, "expected tryTransition to return true on success")
	assertEqual("B enter", calls[1], "expected B to be entered")
	assertEqual(fsm.states.B, fsm.currentState, "expected currentState to become B")
end)

test("tryTransition returns false and stays put when canTransition fails", function()
	local fsm, calls = makeMachine()
	assertFalse(fsm:tryTransition("C") == true, "expected tryTransition to return false on refusal")
	assertEqual(nil, calls[1], "expected no state to be entered")
	assertEqual(fsm.states.A, fsm.currentState, "expected currentState to stay A")
end)
