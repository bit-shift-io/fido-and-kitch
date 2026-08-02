local Log = require('src.utils.log')
local EventBus = require('src.utils.event_bus')
local Collider = require('src.components.collider')

local NPCFollowComponent = Class{}

function NPCFollowComponent:init(entity, config)
    self.entity = entity
    self.config = config or {}
    
    self.movementType = self.config.movementType or 'fly'
    self.followDistance = self.config.followDistance or (self.movementType == 'fly' and 4 or 2)
    self.maxSpeed = self.config.maxSpeed or (self.movementType == 'fly' and 120 or 80)
    self.teleportDistance = self.config.teleportDistance or 20
    self.switchRange = self.config.switchRange or (self.movementType == 'fly' and 8 or 6)
    self.switchInterval = self.config.switchInterval or 3
    self.arrivalRadius = self.config.arrivalRadius or (self.movementType == 'fly' and 2 or 1)
    
    -- Orbit/wander parameters for fly type
    self.minFollowDistance = self.config.minFollowDistance or (self.movementType == 'fly' and 2 or 1)
    self.maxFollowDistance = self.config.maxFollowDistance or (self.movementType == 'fly' and 5 or 3)
    self.orbitSpeed = self.config.orbitSpeed or 30
    self.wanderStrength = self.config.wanderStrength or 0.3
    
    self.targetPlayerIndex = self.config.targetPlayer or 1
    self.velocity = Vector(0, 0)
    
    self.switchTimer = 0
    self.teleportCooldown = 0
    
    self.lastTargetDistance = 0
    self.hysteresisFactor = 0.8
    
    -- Orbit state
    self.orbitAngle = math.random() * math.pi * 2
    self.orbitDirection = math.random() > 0.5 and 1 or -1
    
    if self.movementType == 'hop' then
        self.breadcrumbIndex = 1
        self.onGround = false
        self.jumpVelocity = 250
    end
end

function NPCFollowComponent:setTarget(playerIndex)
    self.targetPlayerIndex = playerIndex
end

function NPCFollowComponent:teleportTo(x, y)
    self.entity.x = x
    self.entity.y = y
    local collider = self.entity:getComponent(Collider)
    if collider then
        collider:setPosition(x, y)
        collider:setLinearVelocity(0, 0)
    end
    self.velocity = Vector(0, 0)
    self:triggerBlink()
end

function NPCFollowComponent:triggerBlink()
    self.entity.alpha = 0
    self.entity.fadeTween = Tween.new(0.2, self.entity, {alpha = 1})
end

function NPCFollowComponent:update(dt)
    self.switchTimer = self.switchTimer + dt
    self.teleportCooldown = math.max(0, self.teleportCooldown - dt)
    
    local targetPlayer = self:getTargetPlayer()
    if not targetPlayer or targetPlayer:isDead() then
        return
    end
    
    local collider = self.entity:getComponent(Collider)
    if not collider then
        return
    end
    
    local targetPos = Vector(targetPlayer.collider:getX(), targetPlayer.collider:getY())
    local npcPos = Vector(collider:getX(), collider:getY())
    local distance = (targetPos - npcPos):len()
    
    if distance > self.teleportDistance * 32 and self.teleportCooldown <= 0 then
        self:teleportToPlayer(targetPlayer)
        return
    end
    
    if self.movementType == 'fly' then
        self:updateFly(dt, targetPos, npcPos, distance)
    elseif self.movementType == 'hop' then
        self:updateHop(dt, targetPlayer, targetPos, npcPos, distance)
    end
    
    self:updateTargetSwitching(dt, targetPlayer, distance)
    
    -- Apply velocity through physics system
    collider:setLinearVelocity(self.velocity.x, self.velocity.y)
end

function NPCFollowComponent:getTargetPlayer()
    if not _G.players then return nil end
    return _G.players[self.targetPlayerIndex]
end

function NPCFollowComponent:updateFly(dt, targetPos, npcPos, distance)
    local minDist = self.minFollowDistance * 32
    local maxDist = self.maxFollowDistance * 32
    
    -- Calculate desired orbit radius (clamped between min and max follow distance)
    local orbitRadius = math.max(minDist, math.min(maxDist, distance))
    
    -- Calculate desired orbit position around target
    local targetOrbitPos = targetPos + Vector(
        math.cos(self.orbitAngle) * orbitRadius,
        math.sin(self.orbitAngle) * orbitRadius
    )
    
    -- Seek toward orbit position
    local toOrbit = targetOrbitPos - npcPos
    local orbitDist = toOrbit:len()
    
    local desiredVelocity
    if orbitDist > 8 then
        -- Move toward orbit position
        desiredVelocity = toOrbit:normalized() * self.maxSpeed
        
        -- Slowly update orbit angle when moving toward position
        self.orbitAngle = self.orbitAngle + self.orbitDirection * self.orbitSpeed * dt * 0.3
    else
        -- At orbit position: settle into stable position instead of constantly orbiting
        -- Only add slight drift/wander, no tangential orbit velocity
        local wander = Vector(
            (math.random() - 0.5) * self.wanderStrength * self.maxSpeed * 0.1,
            (math.random() - 0.5) * self.wanderStrength * self.maxSpeed * 0.1
        )
        desiredVelocity = wander
        
        -- Very slowly drift orbit angle for natural movement
        self.orbitAngle = self.orbitAngle + self.orbitDirection * self.orbitSpeed * dt * 0.05
    end
    
    local steering = desiredVelocity - self.velocity
    self.velocity = self.velocity + steering * dt * 5
    
    if self.velocity:len() > self.maxSpeed then
        self.velocity = self.velocity:normalized() * self.maxSpeed
    end
    
    self:applySeparation()
end

function NPCFollowComponent:applySeparation()
    if not _G.npcEntities then return end
    
    local separation = Vector(0, 0)
    local count = 0
    local npcPos = Vector(self.entity.x, self.entity.y)
    
    for _, other in ipairs(_G.npcEntities) do
        if other ~= self.entity and other.components and other.components.npc_follow then
            local otherPos = Vector(other.x, other.y)
            local diff = npcPos - otherPos
            local dist = diff:len()
            if dist > 0 and dist < 48 then
                separation = separation + diff:normalized() / dist
                count = count + 1
            end
        end
    end
    
    if count > 0 then
        separation = separation / count
        self.velocity = self.velocity + separation * 50
    end
end

function NPCFollowComponent:updateHop(dt, targetPlayer, targetPos, npcPos, distance)
    local history = targetPlayer:getPositionHistory()
    if not history or #history == 0 then
        return
    end
    
    local targetBreadcrumb = self:findTargetBreadcrumb(history, npcPos)
    if not targetBreadcrumb then
        return
    end
    
    local dx = targetBreadcrumb.x - npcPos.x
    local dy = targetBreadcrumb.y - npcPos.y
    
    local moveSpeed = math.min(self.maxSpeed, math.abs(dx) * 10)
    self.velocity.x = dx > 0 and moveSpeed or -moveSpeed
    
    self:checkJump(dt, npcPos)
    
    if self.onGround then
        self.velocity.y = 0
    else
        self.velocity.y = self.velocity.y + 900 * dt
    end
    
    if distance < self.arrivalRadius then
        self.velocity.x = self.velocity.x * (distance / self.arrivalRadius)
    end
end

function NPCFollowComponent:findTargetBreadcrumb(history, npcPos)
    local followDistPixels = self.followDistance * 32
    
    for i = #history, 1, -1 do
        local breadcrumb = history[i]
        local bcPos = Vector(breadcrumb.x, breadcrumb.y)
        local dist = (bcPos - npcPos):len()
        if dist <= followDistPixels then
            return breadcrumb
        end
    end
    
    return history[#history]
end

function NPCFollowComponent:checkJump(dt, npcPos)
    self.onGround = false
    
    if _G.world then
        local collider = self.entity:getComponent(Collider)
        if collider then
            local bounds = collider:getBounds()
            local items, len = _G.world:queryRectangleArea(bounds.left, bounds.bottom + 2, bounds.right, bounds.bottom + 4)
            for _, item in ipairs(items) do
                if item ~= collider and not item.isSensor then
                    self.onGround = true
                    break
                end
            end
        end
    end
    
    if not self.onGround then
        local collider = self.entity:getComponent(Collider)
        if collider then
            local bounds = collider:getBounds()
            local items, len = _G.world:queryRectangleArea(bounds.left, bounds.bottom + 34, bounds.right, bounds.bottom + 36)
            local hasGroundAhead = false
            for _, item in ipairs(items) do
                if item ~= collider and not item.isSensor then
                    hasGroundAhead = true
                    break
                end
            end
            
            if not hasGroundAhead and self.onGround then
                self.velocity.y = -self.jumpVelocity * 0.7
                self.onGround = false
            end
        end
    end
    
    local targetPlayer = self:getTargetPlayer()
    if targetPlayer then
        local history = targetPlayer:getPositionHistory()
        if history and #history >= 2 then
            local latest = history[#history]
            local previous = history[#history - 1]
            if latest.y < previous.y - 8 then
                self.velocity.y = -self.jumpVelocity * 0.7
                self.onGround = false
            end
        end
    end
end

function NPCFollowComponent:updateTargetSwitching(dt, targetPlayer, distance)
    if not _G.players or #_G.players < 2 then return end
    
    local p1 = _G.players[1]
    local p2 = _G.players[2]
    if not p1 or not p2 or p1:isDead() or p2:isDead() then return end
    
    local p1Dist = (Vector(p1.collider:getX(), p1.collider:getY()) - Vector(self.entity.x, self.entity.y)):len()
    local p2Dist = (Vector(p2.collider:getX(), p2.collider:getY()) - Vector(self.entity.x, self.entity.y)):len()
    
    local bothInRange = p1Dist < self.switchRange * 32 and p2Dist < self.switchRange * 32
    if not bothInRange then return end
    
    if self.movementType == 'fly' then
        if self.switchTimer >= self.switchInterval then
            self.switchTimer = 0
            local newTarget = math.random(1, 2)
            if newTarget ~= self.targetPlayerIndex then
                self:setTarget(newTarget)
            end
        end
    elseif self.movementType == 'hop' then
        local currentDist = self.targetPlayerIndex == 1 and p1Dist or p2Dist
        local otherDist = self.targetPlayerIndex == 1 and p2Dist or p1Dist
        local otherIndex = self.targetPlayerIndex == 1 and 2 or 1
        
        if otherDist < currentDist * self.hysteresisFactor then
            self:setTarget(otherIndex)
        end
    end
end

function NPCFollowComponent:teleportToPlayer(targetPlayer)
    local offsetX = math.random(-8, 8)
    local offsetY = math.random(-8, 8)
    self:teleportTo(targetPlayer.collider:getX() + offsetX, targetPlayer.collider:getY() + offsetY)
    self.teleportCooldown = 1
end

function NPCFollowComponent:onPlayerRespawn(playerIndex)
    if playerIndex == self.targetPlayerIndex then
        local player = _G.players[playerIndex]
        if player then
            self:teleportToPlayer(player)
        end
    end
end

return NPCFollowComponent