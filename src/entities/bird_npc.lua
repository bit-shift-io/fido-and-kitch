local Log = require('src.utils.log')
local NPCFollowComponent = require('src.components.npc_follow')

local BirdNPC = Class{__includes = Entity}

function BirdNPC:init(object)
    Entity.init(self, object, 'bird_npc')
    -- object.x and object.y are the top-left of the Tiled object, use center
    local position = Rect.centreOfMapObject(object)
    local shape_arguments = Rect.shapeArgs(32, 32)
    
    self.x = position.x
    self.y = position.y
    
    self.sprite = self:addComponent(Sprite{
        image = 'res/img/npc_bird_idle.png',
        frames = 1,
        duration = 1.0,
        loop = true,
        position = position,
        shape_arguments = shape_arguments,
        playing = true
    })
    
self.collider = self:addComponent(Collider{
        shape_type = 'rectangle',
        shape_arguments = {0, 0, 32, 32},
        body_type = 'dynamic',
        sensor = false,
        position = position,
        gravityScale = 0
    })
    self.collider.isSensor = false
    self.collider.entity = self
    self.collider.nonSolidEntityTypes = {player = true, bird_npc = true, rabbit_npc = true}
    
    local followComponent = NPCFollowComponent(self, {
        movementType = 'fly',
        followDistance = 4,
        maxSpeed = 120,
        teleportDistance = 20,
        switchRange = 8,
        switchInterval = 3,
        arrivalRadius = 2
    })
    self.followComponent = self:addComponent(followComponent)
    
    self.name = 'bird_npc'
    self.type = 'bird_npc'
    
    Log.debug('BirdNPC created at ' .. position.x .. ',' .. position.y)
end

function BirdNPC:update(dt)
    -- Call parent update to process components (including NPCFollowComponent)
    Entity.update(self, dt)
    
    -- Sync entity position from collider (physics system updates collider position)
    if self.collider then
        self.x = self.collider:getX()
        self.y = self.collider:getY()
    end
    
    -- Sync sprite position to entity position
    if self.sprite then
        self.sprite.position.x = self.x
        self.sprite.position.y = self.y
    end
end

function BirdNPC:onSpawn(targetPlayerIndex)
    Log.debug('BirdNPC spawned, following player ' .. targetPlayerIndex)
    if self.followComponent then
        self.followComponent:setTarget(targetPlayerIndex)
    end
end

return BirdNPC
