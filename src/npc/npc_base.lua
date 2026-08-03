-- src/npc/npc_base.lua
local Class = require('lib.hump.class')
local Entity = require('src.entity')
local StateMachine = require('src.components.state_machine')
local Collider = require('src.components.collider')
local Sprite = require('src.components.sprite')
local NPCConfig = require('src.npc.npc_config')
local Rect = require('src.utils.rect')
local Vector = require('lib.hump.vector')

local NPCBase = Class{__includes = Entity}

function NPCBase:init(props, tiledObject)
    props = props or {}
    Entity.init(self, props)
    
    -- Position: use Rect.centreOfMapObject for Tiled tile objects (bottom-edge
    -- anchored), plain x/y for everything else (cage-spawned NPCs, etc.)
    local position
    if tiledObject and tiledObject.gid then
        position = Rect.centreOfMapObject(tiledObject)
    elseif props.x and props.y then
        position = Vector(props.x, props.y)
    else
        position = Vector(0, 0)
    end
    self.x = position.x
    self.y = position.y
    
    -- Merge config with defaults
    self.config = NPCConfig.mergeWithDefaults(props)
    
    -- Health system
    self.health = self.config.health
    self.maxHealth = self.config.health
    self.invulnerableTimer = 0
    
    -- Death/respawn system
    self.deathTimer = 0
    self.RESPAWN_DELAY = 30
    self.deathType = nil
    self.homeX = position.x
    self.homeY = position.y
    self.homeFacing = 'right'
    
    -- Stun/ban system
    self.stunTimer = 0
    self.banTimer = 0
    self.bans = {}
    
    -- Visual properties
    self.visible = true
    self.alpha = 1
    
    -- Target tracking
    self.target = nil
    self.lastKnownTargetPos = nil
    
    -- Patrol state
    self.currentPatrolIndex = 1
    self.patrolDirection = 1
    
    -- Facing direction for sprites and patrol
    self.facing = 'right'
    
    -- Sprite: idle image from config (each subclass sets idleImage in props)
    local w = props.width or 16
    local h = props.height or 16
    -- shape_arguments must include world center position as first 2 values:
    -- world:newCollider unpacks {cx, cy, w, h} and converts to top-left
    local shape_arguments = {position.x, position.y, w, h}
    local idleImage = props.idleImage or self.config.idleImage or 'res/img/npc_spider.png'
    self.animations = self:addComponent(StateMachine{
        states = {
            idle = Sprite{
                image = idleImage,
                frames = 1,
                duration = 1.0,
                loop = false,
                shape_arguments = shape_arguments,
            },
        },
        entity = self,
        currentState = 'idle',
    })
    
    -- Physics setup
    self.collider = self:addComponent(Collider{
        shape_type = 'rectangle',
        shape_arguments = shape_arguments,
        body_type = 'dynamic',
        fixedRotation = true,
        sprite = self.animations,
        solid = true,
        walkable = self.config.ridePlatforms,
    })
    self.collider.owner = self
    self.collider.entity = self
    self.collider.walkable = self.config.ridePlatforms
    -- NPCs must collide with terrain (nil groupIndex). Player uses -1, so
    -- use -2 here: nil != -2 → slide, -1 != -2 → slide, -2 == -2 → skip
    -- (NPC-vs-NPC physical collision is unnecessary).
    self.collider:setGroupIndex(-2)
    
    -- State machine with enhanced FSM states
    local stateMachine = StateMachine{
        stateClasses = {
            IdleState = require('src.npc.states.idle_state'),
            WanderState = require('src.npc.states.wander_state'),
            ChaseState = require('src.npc.states.chase_state'),
            FollowState = require('src.npc.states.follow_state'),
            PatrolState = require('src.npc.states.patrol_state'),
            AttackState = require('src.npc.states.attack_state'),
            FleeState = require('src.npc.states.flee_state'),
            DeadState = require('src.npc.states.dead_state'),
        },
        currentState = 'IdleState',
        entity = self,
    }
    self.stateMachine = self:addComponent(stateMachine)
    
    -- Utility scoring weights (can be overridden per NPC type)
    self.utilityWeights = {
        idle = 10,
        wander = 20,
        chase = 80,
        follow = 70,
        patrol = 30,
        attack = 90,
        flee = 60,
    }
end

function NPCBase:update(dt)
    -- Check for kill zone collisions directly using global world
    if world then
        local bounds = self.collider:getBounds()
        bounds.left = bounds.left + 2
        bounds.right = bounds.right - 2
        bounds.top = bounds.top + 2
        bounds.bottom = bounds.bottom - 2
        
        local cols = world:queryBounds(bounds)
        for _, other in ipairs(cols) do
            if other.entity and other.entity.isKillZone then
                self:die(other.entity.deathType)
                return
            end
        end
    end
    
    -- Calculate utilities and transition state FIRST
    -- Skip if dead - DeadState handles its own transitions
    if not self:isDead() then
        local utilities = self:calculateUtilities()
        local bestState = self:selectBestState(utilities)
        if bestState and bestState ~= self.stateMachine.currentState.name then
            self.stateMachine:setState(bestState)
        end
    end
    
    -- Update invulnerability timer
    if self.invulnerableTimer > 0 then
        self.invulnerableTimer = self.invulnerableTimer - dt
    end
    
    -- Now call Entity.update which will call StateMachine.update -> currentState:update
    Entity.update(self, dt)
    
    -- Sync position from collider after physics
    if self.collider then
        self.x = self.collider:getX()
        self.y = self.collider:getY()
    end
end

function NPCBase:calculateUtilities()
    local utils = {}
    local config = self.config
    local target = self.target
    
    -- Idle: always available, low base score
    utils.idle = self.utilityWeights.idle
    
    -- Wander: available when no target or target far away
    if not target then
        utils.wander = self.utilityWeights.wander
    else
        local dist = (Vector(self.x, self.y) - Vector(target.x, target.y)):len()
        if dist > config.detectionRadius * 1.5 then
            utils.wander = self.utilityWeights.wander * 0.5
        else
            utils.wander = 0
        end
    end
    
    -- Chase: high when target detected and hostile
    if target and config.behavior ~= 'follow' then
        local dist = (Vector(self.x, self.y) - Vector(target.x, target.y)):len()
        if dist <= config.detectionRadius then
            utils.chase = self.utilityWeights.chase * (1 - dist / config.detectionRadius)
        else
            utils.chase = 0
        end
    else
        utils.chase = 0
    end
    
    -- Follow: high when behavior is follow and target exists
    if target and config.behavior == 'follow' then
        local dist = (Vector(self.x, self.y) - Vector(target.x, target.y)):len()
        utils.follow = self.utilityWeights.follow * (1 - math.min(1, dist / (config.detectionRadius * 2)))
    else
        utils.follow = 0
    end
    
    -- Patrol: active when behavior is 'patrol' and no target
    if config.behavior == 'patrol' and not target then
        utils.patrol = self.utilityWeights.patrol
    else
        utils.patrol = 0
    end
    
    -- Attack: very high when in attack range
    if target then
        local dist = (Vector(self.x, self.y) - Vector(target.x, target.y)):len()
        if dist <= config.attackRange then
            utils.attack = self.utilityWeights.attack
        else
            utils.attack = 0
        end
    else
        utils.attack = 0
    end
    
    -- Flee: high when low health
    local healthRatio = self.health / self.maxHealth
    if healthRatio <= config.fleeThreshold then
        utils.flee = self.utilityWeights.flee * (1 - healthRatio)
    else
        utils.flee = 0
    end
    
    return utils
end

function NPCBase:selectBestState(utilities)
    local bestState = nil
    local bestScore = -math.huge
    
    for state, score in pairs(utilities) do
        if score > bestScore then
            bestScore = score
            -- Capitalize first letter to match state class naming (e.g., 'chase' -> 'ChaseState')
            bestState = state:sub(1,1):upper() .. state:sub(2) .. 'State'
        end
    end
    
    return bestState
end

function NPCBase:setTarget(target)
    self.target = target
    if target then
        self.lastKnownTargetPos = {x = target.x, y = target.y}
    end
end

function NPCBase:takeDamage(amount, source)
    if self.invulnerableTimer > 0 then return end
    self.health = math.max(0, self.health - amount)
    self.invulnerableTimer = self.config.invulnerableTime
    if self.health <= 0 then
        self:die(source)
    end
end

function NPCBase:die(source)
    if self:isDead() then
        return -- Already dead, don't overwrite deathType
    end
    self.deathType = source
    -- Transition to DeadState - don't queueRemove, keep entity in world for flash
    self.stateMachine:setState('DeadState')
    -- Call onDeath hook for subclass-specific behavior (e.g., Spider releasing wrapped target)
    if self.onDeath then
        self:onDeath()
    end
end

function NPCBase:respawn()
    self.deathTimer = 0
    self.deathType = nil
    self.health = self.maxHealth
    self.x = self.homeX
    self.y = self.homeY
    if self.collider then
        self.collider:setType('dynamic')
        self.collider:setPosition(self.homeX, self.homeY)
        self.collider:setLinearVelocity(0, 0)
    end
    -- Reset any state
    self.target = nil
    self.lastKnownTargetPos = nil
    self.stunTimer = 0
    self.banTimer = 0
    self.bans = {}
    self.stateMachine:setState('IdleState')
    -- Start spawn flash
    local DeathFlash = require('src.components.death_flash')
    DeathFlash.startSpawn(self)
end

function NPCBase:applyPush(dx, dy)
    if not self.config.canBePushed then return end
    local force = self.config.pushForce
    local vx, vy = self.collider:getLinearVelocity()
    self.collider:setLinearVelocity(vx + dx * force, vy + dy * force)
end

function NPCBase:onCollision(other, dx, dy)
    -- Handle pushing other entities
    if other and other.config and other.config.canBePushed and self.config.canPush then
        local pushDir = (Vector(other.x - self.x, other.y - self.y)):normalized()
        other:applyPush(pushDir.x, pushDir.y)
    end
    
    -- Handle trigger/switch interaction
    if other and other.isSwitch and self.config.triggerSwitches then
        other:activate(self)
    end
    
    -- Handle kill zone interaction
    if other and other.isKillZone then
        self:die(other.deathType)
        return
    end
    
    -- Handle platform riding (for entities with ridePlatforms = true)
    if other and other.isMovingPlatform and self.config.ridePlatforms then
        local otherVx, otherVy = other.collider:getLinearVelocity()
        self.collider:setLinearVelocity(otherVx, otherVy)
    end
end

function NPCBase:isOnGround()
    if self.collider then
        local w = self.collider.world or world
        if not w then return false end
        local bounds = {
            left = self.collider.x,
            right = self.collider.x + self.collider.width,
            top = self.collider.y + self.collider.height + 1,
            bottom = self.collider.y + self.collider.height + 3,
        }
        local items = w:queryOverlap(bounds)
        for _, item in ipairs(items) do
            if item ~= self.collider and not item.sensor then
                return true
            end
        end
    end
    return false
end

function NPCBase:isWallAhead(direction)
    if not self.collider then return false end
    local w = self.collider.world or world
    if not w then return false end
    local checkDist = 8
    local bounds = self.collider:getBounds()
    if direction == 'right' then
        bounds.left = bounds.right
        bounds.right = bounds.right + checkDist
    else
        bounds.right = bounds.left
        bounds.left = bounds.left - checkDist
    end
    bounds.top = bounds.top + 2
    bounds.bottom = bounds.bottom - 2
    local items = w:queryOverlap(bounds)
    for _, item in ipairs(items) do
        if item ~= self.collider then
            if not item.entity and not item.sensor then
                return true
            end
            if item.entity and item.solid and not item.sensor then
                return true
            end
        end
    end
    return false
end

function NPCBase:isGroundAhead(direction)
    if not self.collider then return false end
    local w = self.collider.world or world
    if not w then return false end
    local bounds = self.collider:getBounds()
    local checkDist = 16
    local vertRange = 8
    if direction == 'right' then
        bounds.left = bounds.right
        bounds.right = bounds.right + checkDist
    else
        bounds.right = bounds.left
        bounds.left = bounds.left - checkDist
    end
    bounds.top = bounds.bottom - vertRange
    bounds.bottom = bounds.bottom + vertRange
    local items = w:queryOverlap(bounds)
    for _, item in ipairs(items) do
        if item ~= self.collider then
            if not item.entity and not item.sensor then
                return true
            end
            if item.entity and item.solid and not item.sensor then
                return true
            end
        end
    end
    return false
end

function NPCBase:isDead()
    return self.stateMachine and self.stateMachine.currentState and self.stateMachine.currentState.name == 'DeadState'
end


function NPCBase:stun(duration)
    self.stunTimer = duration or 0
end

function NPCBase:isStunned()
    return self.stunTimer and self.stunTimer > 0
end

function NPCBase:ban(bans, duration)
    self.bans = bans or {}
    self.banTimer = duration or 0
end

return NPCBase