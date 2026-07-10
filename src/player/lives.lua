local Lives = {}

local DEFAULT_LIVES = 2

function Lives.defaultCount()
	return DEFAULT_LIVES
end

function Lives.applyDeath(lives)
	if lives <= 0 then
		return {lives = lives, outcome = 'gameover'}
	end

	return {lives = lives - 1, outcome = 'respawn'}
end

return Lives
