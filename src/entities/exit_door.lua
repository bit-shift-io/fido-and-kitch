-- Exit for actors and players
-- opens on the all_cages_unlocked event (or when its actor counter reaches zero)

local Log = require('src.utils.log')
local EventBus = require('src.utils.event_bus')
local SpriteProps = require('src.entities.sprite_props')

local ExitDoor = Class{__includes = Entity}

-- how far (px, each direction) from the door friendly NPCs are despawned
-- once the exit is used
local DESPAWN_RADIUS = 64

function ExitDoor:init(object)
	Entity.init(self, object, 'exit_door')
	self.state = 'closed'
	self.desiredState = 'closed'
	local position = Rect.centreOfMapObject(object)
    local shape_arguments = Rect.shapeArgs(object.width, object.height)

	-- The sprite fills the authored object's own rect, 1:1 -- like the
	-- blocker. The template (exit_door.tj) is authored at the art size, so
	-- the object box IS the visual footprint; no 2x box and no lift. The
	-- use sensor follows the same rect (bottom-flush). Optional
	-- `spriteOffsetY` (px, positive = down) nudges only the art, tuned from
	-- the running game.
	local spriteOffsetY = tonumber(object.properties.spriteOffsetY) or 0
	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = position + Vector(0, spriteOffsetY)
	spriteProps.shape_arguments = shape_arguments
	spriteProps.finish = utils.bindSelf(ExitDoor.animFinished, self)
	self.sprite = self:addComponent(Sprite(spriteProps))
	self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=shape_arguments,
		body_type='static',
		enter=utils.bindSelf(ExitDoor.contact, self),
		sensor=true,
		position=position
	})
	self.usable = self:addComponent(Usable{
		entity=self,
		use=utils.bindSelf(ExitDoor.use, self),
		enabled=false
	})
	self.variable = self:addComponent(Variable{
        initial=object.properties.actor_count,
		entity=self,
		event=utils.bindSelf(self.event, self)
	})

	self.sound = self:addComponent(Sound{
		sounds = {
			open = 'res/snd/entity_exit_door_open.wav'
		}
	})

	self.entitysWaiting = {}
	self.enableUsableOnOpen = false
	
	-- Initially not usable until all cages are unlocked
	self.cagesUnlocked = false
	
	-- Listen for all_cages_unlocked event
	self.allCagesUnlockedHandler = EventBus.on('all_cages_unlocked', utils.bindSelf(ExitDoor.onAllCagesUnlocked, self))
end

function ExitDoor:onAllCagesUnlocked(data)
    Log.debug('ExitDoor: all cages unlocked, enabling door')
    self.cagesUnlocked = true
    self:open()
end

function ExitDoor:contact(other)
end


function ExitDoor:subtract(v)
    self.variable:subtract(v)
end

function ExitDoor:event(eventName, component)
    self.object:exec(eventName, self)
	if (self.variable.value == 0) then
		self:open()
	end
end

-- open the door for players to exit
-- once opened it cannot be closed
function ExitDoor:open()
	Log.debug('all objectives achived, open door for player to exit')
	self.enableUsableOnOpen = true
	self.state = 'open'
	self.usable.enabled = true
	self.sound:play('open')
	self.sprite.timeline:reset()
	self.sprite.timeline:play()
end


function ExitDoor:use(user)
	self:addWaitingEntity(user)
	self:updateState()
end

function ExitDoor:addWaitingEntity(entity)
	if (self.state == 'open') then
		entity:queueDestroy()
		self:despawnNearbyNPCs()
		return
	end

	table.insert(self.entitysWaiting, entity)
end

function ExitDoor:despawnNearbyNPCs()
	local cx = self.sprite.position.x
	local cy = self.sprite.position.y
	local bounds = {
		left = cx - DESPAWN_RADIUS,
		right = cx + DESPAWN_RADIUS,
		top = cy - DESPAWN_RADIUS,
		bottom = cy + DESPAWN_RADIUS,
	}
	local items = world:queryOverlap(bounds)
	for _, item in ipairs(items) do
		local other = item.entity
		if other and other ~= self and (not other.isDead or not other:isDead()) then
			local isFriendlyNPC = other.config and other.config.despawnDistance > 0
			if isFriendlyNPC then
				Log.debug('ExitDoor: despawning friendly NPC near exit')
				other:queueDestroy()
			end
		end
	end
end

function ExitDoor:updateState(desiredState)
	-- once open for the player to exit, keep it forced open
	if (self.enableUsableOnOpen) then
		desiredState = 'open'
	end

	if (self.state == 'closed' and (desiredState == 'open' or desiredState == 'openThenClose')) then
		self.desiredState = desiredState
		self.state = 'opening'
		self.sprite.timeline:reset()
		self.sprite.timeline:play()
		return
	end

	if (self.state == 'open' and desiredState == 'closed') then
		self.desiredState = desiredState
		self.state = 'closing'
		self.sprite.timeline:resetReverse()
		self.sprite.timeline:play()
		return
	end
end

function ExitDoor:animFinished()
	if (self.state == 'opening') then
		self.state = 'open'
		for _, e in ipairs(self.entitysWaiting) do
			e:queueDestroy()
		end
		self.entitysWaiting = {}
		self:despawnNearbyNPCs()
		if (self.enableUsableOnOpen) then
			self.usable.enabled = true
		end
	elseif (self.state == 'closing') then
		self.state = 'closed'
	end

	if (self.desiredState ~= self.state) then
		if (self.desiredState == 'openThenClose') then
			self:updateState('closed')
		end
	end
end

function ExitDoor:destroy()
    if self.allCagesUnlockedHandler then
        EventBus.off('all_cages_unlocked', self.allCagesUnlockedHandler)
        self.allCagesUnlockedHandler = nil
    end
    -- Call parent destroy if exists
    if Entity.destroy then
        Entity.destroy(self)
    end
end

return ExitDoor
