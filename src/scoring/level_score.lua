local LevelScore = {}

function LevelScore.compute(input)
	local livesRemaining = input.livesRemaining
	local maxLives = input.maxLives
	local coinsCollected = input.coinsCollected
	local totalCoins = input.totalCoins

	-- Calculate lives percentage (0-100)
	local livesPct = (livesRemaining / maxLives) * 100

	-- Calculate coin percentage (0-100)
	-- Zero-coin levels are treated as 100% on the coin half
	local coinsPct
	if totalCoins == 0 then
		coinsPct = 100
	else
		coinsPct = (coinsCollected / totalCoins) * 100
	end

	-- Calculate total percentage as even split (50/50)
	local totalPct = (livesPct + coinsPct) / 2

	-- Determine medal tier
	local medal
	if totalPct == 100 then
		medal = "gold"
	elseif totalPct > 50 then
		medal = "silver"
	else
		medal = "bronze"
	end

	return {
		livesPct = livesPct,
		coinsPct = coinsPct,
		totalPct = totalPct,
		medal = medal,
	}
end

return LevelScore
