local PlayerMovement = {}

function PlayerMovement.decideHorizontalMovement(input, speed, velocityY)
    local velocityX = 0
    local facing = nil
    local animation = 'idle'

    if input.right then
        velocityX = speed
        facing = 'right'
        animation = 'walk'
    end

    if input.left then
        velocityX = -speed
        facing = 'left'
        animation = 'walk'
    end

    return {
        velocityX = velocityX,
        velocityY = velocityY,
        facing = facing,
        animation = animation,
    }
end

function PlayerMovement.nearestLadderCentre(playerCentreX, ladderCentres)
    if #ladderCentres == 0 then
        return nil
    end

    local nearest = ladderCentres[1]
    local minDist = math.abs(playerCentreX - nearest)

    for i = 2, #ladderCentres do
        local centre = ladderCentres[i]
        local dist = math.abs(playerCentreX - centre)
        if dist < minDist then
            minDist = dist
            nearest = centre
        end
    end

    return nearest
end

function PlayerMovement.isCentred(playerCentreX, targetCentreX, slideSpeed, dt)
    local slideStep = slideSpeed * dt
    return math.abs(playerCentreX - targetCentreX) <= slideStep
end

-- Vertical input always wins on a ladder: while up/down is held, left/right
-- is ignored so an accidental side press can't slide the climber off the
-- column mid-climb. Left/right only take the player sideways when neither
-- vertical key is held.
function PlayerMovement.resolveActiveAxis(input)
	if input.verticalHeld then
		return 'vertical'
	end
	if input.horizontalHeld then
		return 'horizontal'
	end
	return nil
end

function PlayerMovement.shouldFallOffLadder(overlapsAnyLadder)
	return not overlapsAnyLadder
end

-- The ladder volume is a no-gravity zone: a player who is airborne (this
-- game has no jump, so airborne always means falling) and overlapping the
-- volume is caught automatically, with no mount key required. A grounded
-- player is never caught -- walking through a ladder's base column behaves
-- like normal ground.
function PlayerMovement.shouldCatchFall(onGround, ladders)
	return not onGround and #ladders > 0
end

-- Which LadderState sub-mode an entry starts in: mounting via up/down
-- begins aligning to the ladder's centre-x as before; a fall catch enters
-- straight into climbing (a hang) so the player is never auto-aligned
-- unless they are actually using the vertical keys.
function PlayerMovement.resolveEntryMode(verticalHeld)
	if verticalHeld then
		return 'aligning'
	end
	return 'climbing'
end

-- Allowed upward climb step for this frame: never overshoot the ladder's
-- top edge. With variable frame timing a plain speed*dt step can carry the
-- player past the top, leaving them mounted but floating above the ladder;
-- clamping against the remaining gap glides exactly to the top and then
-- holds (a zero step = hover).
function PlayerMovement.climbUpStep(feetY, ladderTopY, climbSpeed, dt)
	return math.max(0, math.min(climbSpeed * dt, feetY - ladderTopY))
end

-- When descending onto a ladder that sits flush against the underside of a
-- platform (no gap), the collider's bounds don't overlap the ladder's rect
-- yet -- only the probe just below the feet does -- for as long as the
-- player hasn't moved down into it. Without this, the per-frame "still on a
-- ladder?" check sees no overlap and immediately falls off before the
-- overlap has a chance to register, bouncing the player straight back onto
-- the platform (which re-triggers the mount next frame, and repeats).
-- Folding a ladder detected directly below into the overlap set while
-- descending keeps mounting/aligning/descending continuous until real
-- overlap begins -- including when other ladders ARE overlapped: at a seam
-- the body can graze the up-leading column while the intended down route
-- is the neighbouring one, and both must be alignment candidates.
function PlayerMovement.resolveLadderOverlap(overlappingLadders, downPressed, ladderBelow)
    if not downPressed or not ladderBelow then
        return overlappingLadders
    end

    local resolved = {}
    local alreadyPresent = false
    for _, ladder in ipairs(overlappingLadders) do
        if ladder == ladderBelow then
            alreadyPresent = true
        end
        table.insert(resolved, ladder)
    end
    if not alreadyPresent then
        table.insert(resolved, ladderBelow)
    end
    return resolved
end

function PlayerMovement.applyGravity(collider)
    local _, v_y = collider:getLinearVelocity()
    collider:setLinearVelocity(0, v_y)
end

return PlayerMovement