-- Ground-truth player movement constants, extracted so tools (e.g. the
-- procedural level generator's movement model) can require them headlessly
-- without booting the rest of Player -- which needs a LÖVE image/sprite
-- environment to construct. Values must stay in lockstep with what
-- Player:init assigns.
return {
	speed = 100,
	climbSpeed = 100,
	slideSpeed = 60,
}
