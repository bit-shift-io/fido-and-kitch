-- src/npc/npc_base.lua
local Class = require('lib.hump.class')
local Entity = require('src.entity')
local StateMachine = require('src.components.state_machine')
local Collider = require('src.components.collider')
local NPCConfig = require('src.npc.npc_config')
local Vector = require('lib.hump.vector')

local NPCBase = Class{__includes = Entity}

function NPCBase:init(props)
    props = props or {}
    Entity.init(self, props)
    
    -- Set position from props
    self.x = props.x or 0
    self.y = props.y or 0
    
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
    self.homeX = props.x or 0
    self.homeY = props.y or 0
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
    
-- Physics setup
    local w = props.width or 16
    local h = props.height or 16
    local cx = props.x or 0
    local cy = props.y or 0
    self.collider = self:addComponent(Collider{
        shape_type = 'rectangle',
        shape_arguments = {cx, cy, w, h},
        solid = true,
        walkable = self.config.ridePlatforms,
    })
    self.collider.owner = self
    self.collider.entity = self
    self.collider.walkable = self.config.ridePlatforms
    
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
    
    -- Patrol: only when patrol points defined and no target
    if #config.patrolPoints > 0 and not target then
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
    self.collider.vx = self.collider.vx + dx * force
    self.collider.vy = self.collider.vy + dy * force
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
        self.collider.vx = other.collider.vx
        self.collider.vy = other.collider.vy
    end
end

function NPCBase:isOnGround()
    -- Query physics world for ground contact
    if self.collider and self.collider.world then
        local items, len = self.collider.world:queryRect(
            self.collider.x, self.collider.y + self.collider.height + 1,
            self.collider.width, 2
        )
        for _, item in ipairs(items) do
            if item.solid and item ~= self.collider then
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