local Log = require('src.utils.log')
local EventBus = require('src.utils.event_bus')
local SpriteProps = require('src.entities.sprite_props')

local Cage = Class{__includes = Entity}

function Cage:init(object, map)
	Entity.init(self, object, 'cage')
	local color = object.properties.color
	local position = Rect.centreOfMapObject(object)

	-- The sprite fills the authored object's own rect, 1:1 -- like the
	-- blocker. The template (cage.tj) is authored at the art size, so the
	-- object box IS the visual footprint; no 2x box and no lift. Optional
	-- `spriteOffsetY` (px, positive = down) nudges only the art, tuned from
	-- the running game -- the collider below stays put.
	local spriteOffsetY = tonumber(object.properties.spriteOffsetY) or 0
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = position + Vector(0, spriteOffsetY)
	spriteProps.shape_arguments = shape_arguments
	self.sprite = self:addComponent(Sprite(spriteProps))
	self.lockSprite = self:addComponent(Sprite{
		image=string.format('res/img/cage/cage_lock_%s.png', color),
		frames=1,
		duration=1.0,
		loop=false,
		position=position + Vector(0, spriteOffsetY),
		shape_arguments=shape_arguments,
	})
	-- the use sensor follows the object's own rect too (bottom-flush): the
	-- cage reads at its art footprint rather than a 1x1 tile
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=shape_arguments,
		body_type='static',
		sensor=true,
		position=position
	})
	
	self:addComponent(Usable{
		entity=self,
		use=utils.bindSelf(self.use, self),
		requiredItem=string.format('key_%s', color)
	})

	self.sound = self:addComponent(Sound{
		sounds = {
			open = 'res/snd/entity_cage_open.wav'
		}
	})

	-- Store spawn params; NPC is spawned when the cage is opened, not on map load
	local spawnTypeMap = {
		bird = 'npc_bird',
		rabbit = 'npc_rabbit',
	}
	local spawnType = object.properties.spawn_type or object.properties.actor or 'bird'
	local npcType = spawnTypeMap[spawnType] or spawnType

	-- Resolve target if present (same pattern as switch.lua)
	self.targetObject = nil
	if object.properties.target then
		self.targetObject = map:getObjectById(object.properties.target.id)
	end

	-- Rabbit cage with target is a misconfiguration: log error and ignore target
	if npcType == 'npc_rabbit' and self.targetObject then
		Log.error('Cage spawn_type=rabbit cannot use target property; ignoring target')
		self.targetObject = nil
	end

	-- Let entity type defaults define NPC sprite dimensions
	-- (bird=155x155, rabbit=142x137, etc.)
	local npcProps = {properties = {}}

	-- Spawn the NPC at the cage's own position (Tiled tile objects are
	-- bottom-edge anchored). Use the original object so NPCBase.initPosition
	-- computes the center via Rect.centreOfMapObject; the spawn drop onto the
	-- floor is tuned by the nudge below.
	npcProps.x = object.x
	npcProps.y = object.y
	npcProps.width = object.width
	npcProps.height = object.height
	npcProps.gid = object.gid

	self.spawnNpcType = npcType
	self.spawnLayer = object.layer
	self.spawnNpcProps = npcProps
	self.map = map
end

function Cage:use(user)
	Log.debug('Cage has been used')
	self:removeComponent(self.lockSprite)
	self.sprite.timeline:play()
	self.sound:play('open')

	-- Spawn the NPC before emitting cage_unlocked: opening the LAST cage
	-- makes that emit cascade synchronously into all_cages_unlocked ->
	-- ExitDoor:open() -> exit_door_opened, all before this function returns.
	-- A bird spawned after that emit would subscribe to exit_door_opened
	-- (in BirdNPC:init) too late to catch it, and never fly to the door.
	if self.actor == nil and self.spawnNpcType then
		self.actor = self.map:loadEntity(self.spawnNpcType, self.spawnLayer, self.spawnNpcProps)
	end

	EventBus.emit('cage_unlocked', {cage = self})

	if self.actor == nil then
		return
	end

	-- Hand target to flying NPC if resolved
	if self.spawnNpcType == 'npc_bird' and self.targetObject then
		self.actor.switchTarget = self.targetObject
	end

	-- Nudge up 16px so rabbit spawns above cage and falls cleanly onto floor
	if self.actor.collider then
		local cx, cy = self.actor.x, self.actor.y
		self.actor.collider:setPosition(cx, cy - 16)
		self.actor.x, self.actor.y = cx, cy - 16
	end
	-- Set the NPC to follow the player who opened the cage
	if self.actor.setTarget then
		self.actor:setTarget(user)
	end
end

return Cage