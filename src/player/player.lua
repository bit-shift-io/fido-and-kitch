local PlayerStates = require('src.player.player_states')
local SafePosition = require('src.player.safe_position')
local Flash = require('src.components.flash')
local GroundSupport = require('src.player.ground_support')
local Web = require('src.npc.web')
local PlayerSensors = require('src.player.player_sensors')
local PlayerMovement = require('src.player.player_movement')

local Player = Class{__includes = Entity}

local SPAWN_FLASH_INTERVAL = 0.15
local SPAWN_FLASH_BLINKS = 8
local SPAWN_FADE_DURATION = SPAWN_FLASH_INTERVAL * SPAWN_FLASH_BLINKS

function Player:init(props)
    Entity.init(self)

    local object = props.object
    self.index = props.index
    self.name = 'player'
    self.type = 'player'
    self.ladder = nil
    local character = self.index == 1 and 'dog' or 'cat';
    local height = 50
    local width = 50
    local position = Vector(object.x + width * 0.5, object.y - height * 0.5)
    local offset = Vector(0,8)
    local shape_arguments = {0, 0, width, height}
    local physics_arguments = {0, 0, 20, 30}

    local animations = {
        idle=Sprite{
            frames=string.format('res/img/%s/Idle (${i}).png', character),
            frameCount=10,
            duration=1.0,
            loop=true,
            position=position,
            playing=true,
            shape_arguments=shape_arguments,
            offset=offset,
        },
        fall=Sprite{
            frames=string.format('res/img/%s/Fall (${i}).png', character),
            frameCount=8,
            duration=1.0,
            loop=true,
            position=position,
            playing=true,
            shape_arguments=shape_arguments,
            offset=offset,
        },
        walk=Sprite{
            frames=string.format('res/img/%s/Run (${i}).png', character),
            frameCount=8,
            duration=0.65,
            loop=true,
            position=position,
            playing=true,
            shape_arguments=shape_arguments,
            offset=offset,
        },
        climb=Sprite{
            frames=string.format('res/img/%s/Jump (${i}).png', character),
            frameCount=8,
            duration=1.0,
            loop=true,
            position=position,
            playing=true,
            shape_arguments=shape_arguments,
            offset=offset,
        }
    }

    self.animations = self:addComponent(StateMachine{
        states=animations,
        entity=self,
        currentState='idle'
    })

    self.object = object
    self.speed = 100;
    self.climbSpeed = 100;
    self.facing = 'right'

    self.collider = self:addComponent(Collider{
        shape_type='rectangle',
        shape_arguments=physics_arguments,
        postSolve=utils.forwardFunc(self.contact, self),
        sprite=self.animations,
        position=position,
        entity=self,
        fixedRotation=true
    })
    self.collider:setGroupIndex(-1)

    self.inventory = self:addComponent(Inventory{})

    self.sound = self:addComponent(Sound{
        sounds = {
            jump = 'res/snd/entity_player_jump.wav',
            land = 'res/snd/entity_player_land.wav',
            step = 'res/snd/entity_player_step.wav',
            death = 'res/snd/entity_player_death.wav',
            mount = 'res/snd/entity_ladder_climb.wav',
        }
    })
    self.stepTimer = 0

    self.fsm = self:addComponent(StateMachine{
        stateClasses=PlayerStates,
        entity=self,
        currentState='WalkIdleState'
    })

    self.safePosition = SafePosition.new(position.x, position.y)

    self.visible = true
    self.alpha = 1
    self.deathSignal = Signal{}
end

function Player:setAnimation(name)
    self.animations:setState(name)
end

function Player:setFacing(facing)
    if self.facing == facing then
        return
    end

    self.facing = facing
    for _, animation in pairs(self.animations.states) do
        if animation.setFacing then
            animation:setFacing(facing)
        end
    end
end

function Player:contact(other)
    print('player has made contact with something!')
end

function Player:checkForUsables()
    local x = self.collider:getX()
    local y = self.collider:getY()
    local colls = world:queryRectangleArea(x-1,y-1,x+1,y+1)
    for _, c in ipairs(colls) do
        local entity = c.entity
        if entity then
            local usable = entity:getComponent(Usable)
            if usable ~= nil then
                print('found entity with usable', c.entity.name)
                if usable:canUse(self) then
                    usable:use(self)
                end
            end
        end
    end
end

function Player:update(dt)
    Entity.update(self, dt)

    if self.fadeTween then
        local finished = self.fadeTween:update(dt)
        if finished then
            self.fadeTween = nil
        end
    end

    if not self:isDead() then
        local killZone = PlayerSensors.queryKillZone(world, self.collider)
        if killZone then
            killZone.sound:play(killZone.deathType)
            self:die(killZone.deathType)
        end
    end

    local grounded = self.fsm.currentState == self.fsm.states.WalkIdleState and PlayerSensors.queryFullySupported(world, self.collider:getBounds())
    self.safePosition:update(dt, grounded, self.collider:getX(), self.collider:getY())
end

function Player:draw()
    if self.visible then
        love.graphics.setColor(1, 1, 1, self.alpha)
        Entity.draw(self)
        love.graphics.setColor(1, 1, 1, 1)

        if self.web then
            self.web:draw(self.collider:getBounds())
        end
    end

    if conf.drawphysics then
        self:drawSafePositionMarker()
    end
end

function Player:isDead()
    return self.fsm.currentState == self.fsm.states.DeadState
end

function Player:bounce(force)
    PlayerMovement.applyBounce(self.collider, force)
end

function Player:die(deathType)
    if self:isDead() then
        return
    end

    self.deathType = deathType
    self.fsm:setState('DeadState')
end

function Player:resolveDeath()
    self.deathSignal:emit(self, self.deathType)
end

function Player:wrap(duration)
    if self.wrapped or self:isDead() then
        return
    end

    self.web = Web{duration = duration}
    self.fsm:setState('WrappedState')
end

function Player:respawn()
    self.collider:setPosition(self.safePosition.x, self.safePosition.y)
    self.fsm:setState('WalkIdleState')
    self:startSpawnFlash()
end

function Player:startSpawnFlash()
    self.alpha = 0
    self.fadeTween = Tween.new(SPAWN_FADE_DURATION, self, {alpha = 1})

    self.flash = self:addComponent(Flash{
        target = self,
        property = 'visible',
        interval = SPAWN_FLASH_INTERVAL,
        blinks = SPAWN_FLASH_BLINKS,
    })
end

function Player:drawSafePositionMarker()
    local size = 6
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.line(self.safePosition.x - size, self.safePosition.y, self.safePosition.x + size, self.safePosition.y)
    love.graphics.line(self.safePosition.x, self.safePosition.y - size, self.safePosition.x, self.safePosition.y + size)
    love.graphics.setColor(1, 1, 1, 1)
end

function Player:pickup(pickup)
    local entity = pickup.entity
    print('player picked up a ' .. pickup.itemName)
    local sound = entity:getComponent(Sound)
    if sound ~= nil then
        sound:play('pickup')
    end
    self.inventory:addItems(pickup.itemName, pickup.itemCount)
    entity:queueDestroy()
end

function Player:queryOnGround()
    return PlayerSensors.queryOnGround(world, self.collider)
end

function Player:queryFullySupported()
    return PlayerSensors.queryFullySupported(world, self.collider:getBounds())
end

function Player:isDown(action)
    return inputManager:isDown(self.index, action)
end

return Player