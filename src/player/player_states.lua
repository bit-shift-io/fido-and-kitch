local LadderState = require("src.player.states.ladder_state")
local WalkIdleState = require("src.player.states.walk_idle_state")
local FallState = require("src.player.states.fall_state")
local DeadState = require("src.player.states.dead_state")
local WrappedState = require("src.player.states.wrapped_state")
local TeleportTravelState = require("src.player.states.teleport_travel_state")
local JumpTravelState = require("src.player.states.jump_travel_state")

return {
	LadderState = LadderState,
	WalkIdleState = WalkIdleState,
	FallState = FallState,
	DeadState = DeadState,
	WrappedState = WrappedState,
	TeleportTravelState = TeleportTravelState,
	JumpTravelState = JumpTravelState,
}
