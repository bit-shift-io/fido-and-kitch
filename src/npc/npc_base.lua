-- src/npc/npc_base.lua
local Class = require('lib.hump.class')
local Entity = require('src.entity')
local StateMachine = require('src.components.state_machine')
local Collider = require('src.components.collider')
local Sprite = require('src.components.sprite')
local FlashEffect = require('src.components.flash_effect')
local NPCConfig = require('src.npc.npc_config')
local SpawnFlash = require('src.utils.spawn_flash')
local Rect = require('src.utils.rect')
local Vector = require('lib.hump.vector')

local NPCBase = Class{__includes = Entity}

-- Spatial probe constants (world px) used by the collision queries below.
local KILL_ZONE_INSET = 2            -- shrink the hitbox when probing kill zones
local GROUND_PROBE = {min = 1, max = 3} -- probe band just below the feet
local WALL_PROBE_DIST = 8            -- how far ahead a wall check reaches
local WALL_PROBE_INSET = 2           -- vertical inset of the wall probe
local GROUND_AHEAD_PROBE_DIST = 16   -- how far ahead a ground check reaches
local GROUND_AHEAD_VERT_RANGE = 8    -- vertical range of the ground probe

-- Shared "is anything solid in these bounds" scan used by the ground/wall
-- probes below. With requireSolid=true only terrain (no owning entity) and
-- solid entities count; with requireSolid=false any non-sensor collider does.
local function querySolidIn(world, collider, bounds, requireSolid)
    local items = world:queryOverlap(bounds)
    for _, item in ipairs(items) do
        if item ~= collider and not item.sensor then
            if not requireSolid or not item.entity or item.solid then
                return true
            end
        end
    end
    return false
end

function NPCBase:init(props, tiledObject)
    props = props or {}
    Entity.init(self, props)
    self:initPosition(props, tiledObject)
    self:initCoreState(props)
    self:initVisuals(props)
    self:initPhysics(props)
    self:initStateMachine()
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

function NPCBase:initPosition(props, tiledObject)
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
    self.homeX = position.x
    self.homeY = position.y
end

function NPCBase:initCoreState(props)
    -- Merge config with defaults
    self.config = NPCConfig.mergeWithDefaults(props)

    -- Health system
    self.health = self.config.health
    self.maxHealth = self.config.health
    self.invulnerableTimer = 0

    -- Death/respawn system
    self.deathTimer = 0
    self.RESPAWN_DELAY = 2
    self.deathType = nil

    -- Visual properties
    self.visible = true
    self.alpha = 1

    -- Target tracking
    self.target = nil
    self.lastKnownTargetPos = nil

    -- Facing direction for sprites and patrol
    self.facing = 'right'
end

function NPCBase:initVisuals(props)
    local w = props.width or 16
    local h = props.height or 16
    -- shape_arguments carry dimensions only ({w, h}); position is supplied
    -- separately via props.position (Collider's setPositionV)
    local spriteArgs = {w, h}
    local idleImage = props.idleImage or self.config.idleImage or 'res/img/npc_spider.png'
    -- FlashEffect must be added BEFORE the sprite StateMachine so its draw()
    -- sets the color before the sprite renders (no one-frame delay).
    self.flashEffect = self:addComponent(FlashEffect{})
    self.animations = self:addComponent(StateMachine{
        states = {
            idle = Sprite{
                image = idleImage,
                frames = 1,
                duration = 1.0,
                loop = false,
                shape_arguments = spriteArgs,
            },
        },
        entity = self,
        currentState = 'idle',
    })
end

function NPCBase:initPhysics(props)
    local w = props.width or 16
    local h = props.height or 16
    local cw = props.colliderWidth or w
    local ch = props.colliderHeight or h
    -- shape_arguments carry dimensions only ({w, h}); position is supplied
    -- separately via props.position (Collider's setPositionV)
    local colliderArgs = {cw, ch}
    self.collider = self:addComponent(Collider{
        shape_type = 'rectangle',
        shape_arguments = colliderArgs,
        body_type = 'dynamic',
        fixedRotation = true,
        sprite = self.animations,
        solid = true,
        walkable = self.config.ridePlatforms,
        position = Vector(self.x, self.y),
    })
    self.collider.owner = self
    self.collider.entity = self
    self.collider.walkable = self.config.ridePlatforms
    -- NPCs must collide with terrain (nil groupIndex). Player uses -1, so
    -- use -2 here: nil != -2 → slide, -1 != -2 → slide, -2 == -2 → skip
    -- (NPC-vs-NPC physical collision is unnecessary).
    self.collider:setGroupIndex(-2)
end

function NPCBase:initStateMachine()
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
end

-- Kill-zone overlap check: probe the world just inside the collider bounds
-- and die immediately if any kill zone is found.
local function checkKillZones(npc)
    if not world then return end
    local bounds = npc.collider:getBounds()
    bounds.left   = bounds.left   + KILL_ZONE_INSET
    bounds.right  = bounds.right  - KILL_ZONE_INSET
    bounds.top    = bounds.top    + KILL_ZONE_INSET
    bounds.bottom = bounds.bottom - KILL_ZONE_INSET

    local cols = world:queryBounds(bounds)
    for _, other in ipairs(cols) do
        if other.entity and other.entity.isKillZone then
            npc:die(other.entity.deathType)
            return true
        end
    end
    return false
end

-- Scan all players and set the NPC's target to the closest one within
-- detection radius.
local function detectNearestPlayer(npc)
    if not players or #players == 0 then return end
    local closest, closestDist = nil, npc.config.detectionRadius
    for _, player in ipairs(players) do
        if player and not player.dead and player.collider then
            local px = player.collider:getX()
            local py = player.collider:getY()
            local dx, dy = px - npc.x, py - npc.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < closestDist then
                closestDist = dist
                closest = {x = px, y = py}
            end
        end
    end
    npc:setTarget(closest)
end

-- Despawn a friendly NPC that has wandered beyond its configured radius
-- from the current target.
local function checkDespawn(npc)
    if npc.config.despawnDistance <= 0 or not npc.target or npc:isDead() then
        return
    end
    local tx, ty = npc:getTargetPos()
    if not tx then return end
    local dx, dy = tx - npc.x, ty - npc.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > npc.config.despawnDistance then
        npc:despawnToTarget()
    end
end

function NPCBase:update(dt)
    -- Kill zones first — no update logic should run after death
    if checkKillZones(self) then return end

    -- Detect nearby players for follow/chase behavior
    detectNearestPlayer(self)

    -- Despawn to target if too far away (friendly NPCs)
    checkDespawn(self)

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

    -- Compute target distance once for all branches that need it
    local tx, ty, dist
    if target then
        tx, ty = self:getTargetPos()
        dist = (Vector(self.x, self.y) - Vector(tx, ty)):len()
    end

    -- Wander: available when no target or target far away
    if not target then
        utils.wander = self.utilityWeights.wander
    else
        if dist > config.detectionRadius * 1.5 then
            utils.wander = self.utilityWeights.wander * 0.5
        else
            utils.wander = 0
        end
    end

    -- Chase: high when target detected and hostile
    if target and config.behavior ~= 'follow' then
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
        local tx, ty
        if target.collider then
            tx, ty = target.collider:getX(), target.collider:getY()
        else
            tx, ty = target.x, target.y
        end
        self.lastKnownTargetPos = {x = tx, y = ty}
    end
end

function NPCBase:getTargetPos()
    if not self.target then return nil end
    if self.target.collider then
        return self.target.collider:getX(), self.target.collider:getY()
    end
    return self.target.x, self.target.y
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
    self.stateMachine:setState('IdleState')
    -- Start spawn flash
    self.flashEffect:fadeIn(SpawnFlash.FADE * SpawnFlash.BLINKS)
    self.flashEffect:blink(SpawnFlash.FADE, SpawnFlash.BLINKS)
end

function NPCBase:isOnGround()
    if self.collider then
        local w = self.collider.world or world
        if not w then return false end
        local bounds = {
            left = self.collider.x,
            right = self.collider.x + self.collider.width,
            top = self.collider.y + self.collider.height + GROUND_PROBE.min,
            bottom = self.collider.y + self.collider.height + GROUND_PROBE.max,
        }
        return querySolidIn(w, self.collider, bounds, false)
    end
    return false
end

function NPCBase:isWallAhead(direction)
    if not self.collider then return false end
    local w = self.collider.world or world
    if not w then return false end
    local bounds = self.collider:getBounds()
    if direction == 'right' then
        bounds.left = bounds.right
        bounds.right = bounds.right + WALL_PROBE_DIST
    else
        bounds.right = bounds.left
        bounds.left = bounds.left - WALL_PROBE_DIST
    end
    bounds.top = bounds.top + WALL_PROBE_INSET
    bounds.bottom = bounds.bottom - WALL_PROBE_INSET
    return querySolidIn(w, self.collider, bounds, true)
end

function NPCBase:isGroundAhead(direction)
    if not self.collider then return false end
    local w = self.collider.world or world
    if not w then return false end
    local bounds = self.collider:getBounds()
    if direction == 'right' then
        bounds.left = bounds.right
        bounds.right = bounds.right + GROUND_AHEAD_PROBE_DIST
    else
        bounds.right = bounds.left
        bounds.left = bounds.left - GROUND_AHEAD_PROBE_DIST
    end
    bounds.top = bounds.bottom - GROUND_AHEAD_VERT_RANGE
    bounds.bottom = bounds.bottom + GROUND_AHEAD_VERT_RANGE
    return querySolidIn(w, self.collider, bounds, true)
end

function NPCBase:isDead()
    return self.stateMachine and self.stateMachine.currentState and self.stateMachine.currentState.name == 'DeadState'
end

function NPCBase:despawnToTarget()
    local tx, ty = self:getTargetPos()
    if not tx then return end
    self.x = tx
    self.y = ty
    if self.collider then
        self.collider:setPosition(tx, ty)
        self.collider:setLinearVelocity(0, 0)
    end
    self.stateMachine:setState('IdleState')
    self.flashEffect:fadeIn(SpawnFlash.FADE * SpawnFlash.BLINKS)
    self.flashEffect:blink(SpawnFlash.FADE, SpawnFlash.BLINKS)
end


return NPCBase