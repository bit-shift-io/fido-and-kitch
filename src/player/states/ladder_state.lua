local PlayerMovement = require("src.player.player_movement")
local PlayerSensors = require("src.player.player_sensors")
local Log = require("src.utils.log")

local LadderState = Class({})

local HALF_TILE = 16

function LadderState:enter()
	Log.debug("ladder enter")
	local player = self.entity
	player:setAnimation("climb")
	player.collider:setType("kinematic")
	player.collider:setGravityScale(0)
	player.sound:play("mount")

	local verticalHeld = player:isDown("up") or player:isDown("down")
	self.mode = PlayerMovement.resolveEntryMode(verticalHeld)
	self.targetCentreX = nil
	self.isInitialMount = verticalHeld

	if player:isDown("down") then
		local below = PlayerSensors.queryLadderBelow(world, player.collider)
		if below then
			self.targetCentreX = below.rect:centre().x
		end
	end

	player.verticalHeld = verticalHeld
	player.horizontalHeld = player:isDown("left") or player:isDown("right")
end

function LadderState:exit()
	local player = self.entity
	player.collider:setType("dynamic")
	player.collider:setGravityScale(1)
	player.collider:setLinearVelocity(0, 0)

	if self.mode == "sliding" then
		player.ladderCatchGrace = 0.2
	end
end

function LadderState:canTransition()
	local player = self.entity
	local ladders = PlayerSensors.queryAllLadders(world, player.collider)

	if player:isDown("up") then
		if #ladders > 0 then
			return true
		end
	end

	if player:isDown("down") then
		local ladderBelow = PlayerSensors.queryLadderBelow(world, player.collider)
		if ladderBelow then
			return true
		end
	end

	return false
end

local function snapOntoGround(player, ground)
	local b = player.collider:getBounds()
	local other = ground.other
	local top = other and other:getBounds().top
	if not top then
		return
	end
	player.collider:setPosition(player.collider:getX(), top - b.height / 2)
end

function LadderState:update(dt)
	local player = self.entity

	local downPressed = player:isDown("down")
	local upPressed = player:isDown("up")
	local leftPressed = player:isDown("left")
	local rightPressed = player:isDown("right")

	local directLadders = PlayerSensors.queryAllLadders(world, player.collider)
	local ladderBelowForOverlap = nil
	if downPressed then
		ladderBelowForOverlap = PlayerSensors.queryLadderBelow(world, player.collider)
	end
	local ladders = PlayerMovement.resolveLadderOverlap(directLadders, downPressed, ladderBelowForOverlap)

	if downPressed and ladderBelowForOverlap == nil then
		local ground = PlayerSensors.queryOnNonLadderGround(world, player.collider)
		if ground then
			snapOntoGround(player, ground)
			player.fsm:setState("WalkIdleState")
			return
		end
	end

	-- Falling off must not wait for a vertical key to be released: a climber
	-- holding up who slides sideways off the column (up+left/right switches
	-- the sub-mode to sliding) would otherwise keep zero-gravity and sail
	-- across the map. The one exception is the top hover, where the body is
	-- flush against the top edge (no volume overlap) but the column is still
	-- directly under the feet -- pressing up there must stay mounted, not
	-- pop the player off. The down-fold above already covers descent, so
	-- the below-feet probe below only needs to protect the up-held hover.
	if PlayerMovement.shouldFallOffLadder(#ladders > 0) then
		local anchoredAbove = upPressed and PlayerSensors.queryLadderBelow(world, player.collider)
		if not anchoredAbove then
			local ground = PlayerSensors.queryOnNonLadderGround(world, player.collider)
			if ground then
				snapOntoGround(player, ground)
				player.fsm:setState("WalkIdleState")
			else
				player.fsm:setState("FallState")
			end
			return
		end
	end

	local verticalHeld = upPressed or downPressed
	local horizontalHeld = leftPressed or rightPressed

	local verticalNewlyPressed = verticalHeld and not player.verticalHeld
	local horizontalNewlyPressed = horizontalHeld and not player.horizontalHeld

	player.verticalHeld = verticalHeld
	player.horizontalHeld = horizontalHeld
	player.verticalNewlyPressed = verticalNewlyPressed
	player.horizontalNewlyPressed = horizontalNewlyPressed

	local activeAxis = PlayerMovement.resolveActiveAxis({
		verticalHeld = verticalHeld,
		horizontalHeld = horizontalHeld,
		verticalNewlyPressed = verticalNewlyPressed,
		horizontalNewlyPressed = horizontalNewlyPressed,
		previousAxis = player.previousLadderAxis,
	})

	if activeAxis then
		player.previousLadderAxis = activeAxis
	end

	local playerCentreX = player.collider:getX()
	local ladderCentres = {}
	for _, ladder in ipairs(ladders) do
		table.insert(ladderCentres, ladder.rect:centre().x)
	end

	local velocityX = 0
	local velocityY = 0
	local movingOnLadder = false
	local exited = false

	if self.mode == "aligning" then
		velocityX, velocityY, movingOnLadder, exited = self:updateAligning(player, playerCentreX, ladderCentres, dt)
	elseif self.mode == "climbing" then
		velocityX, velocityY, movingOnLadder, exited =
			self:updateClimbing(player, upPressed, downPressed, activeAxis, ladderCentres, dt)
	elseif self.mode == "sliding" then
		velocityX, velocityY, movingOnLadder, exited =
			self:updateSliding(player, activeAxis, leftPressed, rightPressed, ladders, dt)
	end

	if exited then
		return
	end

	player.collider:setLinearVelocity(velocityX, velocityY)
	local anim = player.animations.currentState
	anim.playing = movingOnLadder
	if not movingOnLadder then
		anim:setFrameNum(1)
	end
end

function LadderState:updateAligning(player, playerCentreX, ladderCentres, dt)
	if not self.targetCentreX and #ladderCentres > 0 then
		self.targetCentreX = PlayerMovement.nearestLadderCentre(playerCentreX, ladderCentres)
	end

	if not self.targetCentreX then
		player.fsm:setState("FallState")
		return 0, 0, false, true
	end

	local slideSpeed = self.isInitialMount and player.speed or player.slideSpeed
	local centred = PlayerMovement.isCentred(playerCentreX, self.targetCentreX, slideSpeed, dt)

	if centred then
		player.collider:setX(self.targetCentreX)
		self.mode = "climbing"
		self.isInitialMount = false
		return 0, 0, false, false
	end

	local direction = self.targetCentreX > playerCentreX and 1 or -1
	return direction * slideSpeed, 0, true, false
end

function LadderState:updateClimbing(player, upPressed, downPressed, activeAxis, ladderCentres, dt)
	if activeAxis ~= "vertical" then
		if activeAxis == "horizontal" and not player.horizontalNewlyPressed then
			return 0, 0, false, false
		end
		self.mode = "sliding"
		return 0, 0, false, false
	end

	if upPressed or downPressed then
		local centreX = self.targetCentreX
		if not centreX and #ladderCentres > 0 then
			centreX = PlayerMovement.nearestLadderCentre(player.collider:getX(), ladderCentres)
		end
		if centreX and math.abs(player.collider:getX() - centreX) > 1 then
			self.targetCentreX = centreX
			self.mode = "aligning"
			self.isInitialMount = false
			return 0, 0, false, false
		end
	end

	if upPressed then
		local ladders = PlayerSensors.queryAllLadders(world, player.collider)
		if #ladders > 0 then
			local feetY = player.collider:getBounds().bottom
			local topY
			for _, ladder in ipairs(ladders) do
				local rect = ladder.rect
				local ladderTop = rect.y - rect.height
				if not topY or ladderTop < topY then
					topY = ladderTop
				end
			end
			local step = PlayerMovement.climbUpStep(feetY, topY, player.climbSpeed, dt)
			if step <= 0 then
				return 0, 0, false, false
			end
			return 0, -step / dt, true, false
		end

		return 0, 0, false, false
	elseif downPressed then
		local ladderBelow = PlayerSensors.queryLadderBelow(world, player.collider)
		if ladderBelow then
			return 0, player.climbSpeed, true, false
		end
		return 0, 0, false, false
	end

	return 0, 0, false, false
end

function LadderState:updateSliding(player, activeAxis, leftPressed, rightPressed, ladders, dt)
	if activeAxis == "vertical" then
		self.mode = "aligning"
		self.isInitialMount = false
		return 0, 0, false, false
	end

	local function finishClimbOrSlide(direction)
		if not atTop and topY and feet <= topY + HALF_TILE then
			local rise = PlayerMovement.climbUpStep(feet, topY, player.climbSpeed, dt)
			if rise > 0 then
				return 0, -rise / dt, true, false
			end
		end
		return direction * player.slideSpeed, 0, true, false
	end

	local atTop = false
	local topY
	local feet = player.collider:getBounds().bottom
	for _, ladder in ipairs(ladders) do
		local ladderTop = ladder.rect.y - ladder.rect.height
		if not topY or ladderTop < topY then
			topY = ladderTop
		end
		if feet <= topY + 3 then
			atTop = true
			break
		end
	end

	if leftPressed then
		local blocked = PlayerSensors.queryHorizontalBlock(world, player.collider, "left")
		if not blocked then
			return finishClimbOrSlide(-1)
		end
	elseif rightPressed then
		local blocked = PlayerSensors.queryHorizontalBlock(world, player.collider, "right")
		if not blocked then
			return finishClimbOrSlide(1)
		end
	end

	return 0, 0, false, false
end

return LadderState
