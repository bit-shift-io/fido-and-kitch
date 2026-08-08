-- Self-contained seeded PRNG (LCG, Numerical Recipes constants). Deliberately
-- not math.random: batch items must be independently reproducible from a
-- base seed without touching global RNG state.
local Rng = {}
Rng.__index = Rng

local MODULUS = 4294967296 -- 2^32
local MULTIPLIER = 1664525
local INCREMENT = 1013904223

function Rng.new(seed)
	return setmetatable({state = seed % MODULUS}, Rng)
end

function Rng:nextUint32()
	self.state = (self.state * MULTIPLIER + INCREMENT) % MODULUS
	return self.state
end

function Rng:next()
	return self:nextUint32() / MODULUS
end

function Rng:nextInt(minInclusive, maxInclusive)
	local range = maxInclusive - minInclusive + 1
	return minInclusive + (self:nextUint32() % range)
end

-- Derives batch item i's seed from a base seed so each item is independently
-- reproducible regardless of how many other items are generated alongside it.
function Rng.deriveSeed(baseSeed, index)
	local mixed = (baseSeed + index * 2654435761) % MODULUS
	return (mixed * MULTIPLIER + INCREMENT) % MODULUS
end

return Rng
