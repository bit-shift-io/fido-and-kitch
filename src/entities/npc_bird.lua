-- src/entities/npc_bird.lua
local Class = require("lib.hump.class")
local NPCBase = require("src.npc.npc_base")
local NPCConfig = require("src.npc.npc_config")
local NPCRegistry = require("src.npc.npc_registry")
local EventBus = require("src.utils.event_bus")
local Entity = require("src.entity")

local BirdNPC = Class({ __includes = NPCBase })

-- Register type at module load time
NPCRegistry.registerType("npc_bird", BirdNPC)

-- Flight speed (px/s) used by FlyToTargetState's PathFollow when this bird
-- flies its cage-to-switch swoop curve. Read generically off the entity
-- (entity.targetFlightSpeed) by fly_to_target_state.lua, rather than a
-- global, so future species can supply their own.
local TARGET_FLIGHT_SPEED = 150

function BirdNPC:init(props)
	props = props or {}
	local merged = NPCConfig.getDefaults()

	-- genuinely per-NPC overrides on top of the shared defaults
	merged.idleImage = "res/img/npc_bird_idle.png"
	merged.width = 32
	merged.height = 32
	merged.colliderWidth = 16
	merged.colliderHeight = 16
	merged.canFly = true
	merged.despawnDistance = 200
	merged.maxSpeed = 100
	merged.acceleration = 300
	merged.detectionRadius = 500
	merged.attackRange = 0
	merged.damage = 0
	merged.behavior = "follow"
	merged.fleeThreshold = 0.5
	merged.followDistance = 60

	-- Tiled object props win over every default
	for k, v in pairs(props) do
		merged[k] = v
	end

	NPCBase.init(self, merged)

	-- Always a sensor: a bird ignores terrain collision entirely (flies
	-- freely, gravity handled manually) rather than colliding solidly
	-- outside ladder volumes. This also means a directed flight
	-- (FlyToTargetState/FlyToDoorState) never freezes mid-arc against
	-- ordinary terrain the way PathFollow's obstacle-freeze would for a
	-- solid collider -- see PathFollow:_isBlocked.
	self.collider:setSensor(true)
	self.collider:setGravityScale(0)

	self.targetFlightSpeed = TARGET_FLIGHT_SPEED

	-- Once the exit door opens, every following bird detaches and flies its
	-- own swoop arc to the door, overriding whatever it's currently doing
	-- (including a still-in-progress FlyToTargetState) -- see
	-- fly_to_door_state.lua. Unconditional, unlike the switchTarget check in
	-- update() below, because it must interrupt an in-progress forced state.
	self.exitDoorOpenedHandler = EventBus.on("exit_door_opened", utils.bindSelf(BirdNPC.onExitDoorOpened, self))
end

function BirdNPC:onExitDoorOpened(data)
	self.forcedState = "FlyToDoorState"
	self.forcedStateParams = data.position
end

function BirdNPC:update(dt)
	-- Cage:use spawns the bird (running BirdNPC:init) BEFORE it assigns
	-- switchTarget onto the actor, so switchTarget is never present yet at
	-- init time -- it can only be checked lazily here, on the first update
	-- after the cage hands it over. flownToTarget guards this from firing
	-- again once the flight has completed (switchTarget itself is left set,
	-- as a record of where this bird flew).
	if self.switchTarget and not self.flownToTarget and not self.forcedState then
		self.forcedState = "FlyToTargetState"
	end

	NPCBase.update(self, dt)
end

function BirdNPC:destroy()
	if self.exitDoorOpenedHandler then
		EventBus.off("exit_door_opened", self.exitDoorOpenedHandler)
		self.exitDoorOpenedHandler = nil
	end
	-- NPCBase does not define its own destroy(); fall back to Entity's base
	-- implementation directly (mirrors ExitDoor:destroy()'s own pattern).
	if NPCBase.destroy then
		NPCBase.destroy(self)
	else
		Entity.destroy(self)
	end
end

return BirdNPC
