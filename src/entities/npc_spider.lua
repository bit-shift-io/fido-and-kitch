-- src/entities/npc_spider.lua
local Class = require("lib.hump.class")
local NPCBase = require("src.npc.npc_base")
local NPCConfig = require("src.npc.npc_config")
local NPCRegistry = require("src.npc.npc_registry")

local Spider = Class({ __includes = NPCBase })

-- Hostile (behavior='chase', damage=1) -- a laser beam passes through it and
-- kills it, same as a player. See NPCBase.isEnemy's comment for why this is
-- set per-species rather than as NPCBase's own default.
Spider.isEnemy = true

-- Register type at module load time
NPCRegistry.registerType("npc_spider", Spider)

function Spider:init(props)
	props = props or {}
	local merged = NPCConfig.getDefaults()

	-- genuinely per-NPC overrides on top of the shared defaults
	merged.idleImage = "res/img/npc_spider.png"
	merged.maxSpeed = 90
	merged.acceleration = 350
	merged.detectionRadius = 200
	merged.attackRange = 24
	merged.damage = 1
	merged.health = 2
	merged.behavior = "chase"
	merged.fleeThreshold = 0.25

	-- Tiled object props win over every default
	for k, v in pairs(props) do
		merged[k] = v
	end

	NPCBase.init(self, merged)
end

-- Override onDeath to release any wrapped target immediately
function Spider:onDeath()
	if self.wrappedTarget and self.wrappedTarget.wrapped then
		self.wrappedTarget:releaseWrap()
	end
	self.wrappedTarget = nil
end

return Spider
