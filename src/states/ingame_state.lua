local Lives = require("src.player.lives")
local GameHud = require("src.ui.game_hud")
local AutoCamera = require("src.camera")
local EventBus = require("src.utils.event_bus")
local DebugOverlay = require("src.ui.debug_overlay")
local SpriteOutlineOverlay = require("src.ui.sprite_outline_overlay")
local GridOverlay = require("src.ui.grid_overlay")
local BaseState = require("src.states.base_state")
local Log = require("src.utils.log")
local Diorama = require("src.diorama")

local InGameState = Class({ __includes = BaseState })

local GAME_OVER_ZOOM_DELAY = 0.6
local WORLD_GRAVITY_Y = 90.81

-- Voronoi split compositing parameters (only used when conf.voronoi is on).
local SPLIT_DIVERGENCE_FLOOR = 8 -- pane separation before the line starts growing
local SPLIT_FULL_DIVERGENCE = 192 -- pane separation where the split is fully grown
local VORONOI_LINE_THICKNESS = 10.0 -- dividing line width in screen px at full growth
local VORONOI_LINE_COLOR = { 0.0, 0.0, 0.0 } -- RGB of the dividing line (black)

local function spawnPlayers(self, map, playerCount)
	local players = {}
	local spawnPoints = {}
	for _, layer in ipairs(map.layers) do
		if layer.type == "objectgroup" then
			for _, object in ipairs(layer.objects) do
				if object.type == "spawn" then
					table.insert(spawnPoints, { object = object, layer = layer })
				end
			end
		end
	end
	for i = 1, playerCount do
		local spawnPoint = spawnPoints[(i - 1) % math.max(#spawnPoints, 1) + 1]
		if not spawnPoint then
			break
		end
		local entity = Player({ object = spawnPoint.object, index = i })
		entity.destroySignal:connect(utils.bindSelf(InGameState.onPlayerDestroyed, self))
		entity:startSpawnFlash()
		table.insert(spawnPoint.layer.entities, entity)
		table.insert(players, entity)
	end
	return players
end

local function initCages(self, map)
	local cages = map:getEntitiesByType("cage")
	self.totalCages = #cages
	self.unlockedCages = 0
	Log.debug("Level has " .. self.totalCages .. " cages")
	for _, cage in ipairs(cages) do
		cage.totalCages = self.totalCages
		cage.unlockedCount = 0
	end
	self.cageUnlockedHandler = EventBus.on("cage_unlocked", utils.bindSelf(InGameState.onCageUnlocked, self))
end

local function initCoins(self, map)
	self.totalCoins = #map:getEntitiesByType("coin")
	self.coinsCollected = 0
	self.coinCollectedHandler = EventBus.on("coin_collected", utils.bindSelf(InGameState.onCoinCollected, self))
end

function InGameState:enter()
	Log.debug("ingame enter")
end

function InGameState:load(props)
	if profile then
		profile.start()
	end

	local NPCRegistry = require("src.npc.npc_registry")
	NPCRegistry.clear()

	self.currentMap = props.map or "res/map/sandbox.tmj"
	Log.debug("loading map: " .. self.currentMap)

	_G.world = World:new(0, WORLD_GRAVITY_Y, true)
	_G.map = Map:new(self.currentMap, world, true)

	local mapW, mapH = map:getPixelSize()
	self.camera = AutoCamera.CameraManager.new({
		screenW = love.graphics.getWidth(),
		screenH = love.graphics.getHeight(),
		mapW = mapW,
		mapH = mapH,
		tileW = map.map.tilewidth,
		tileH = map.map.tileheight,
		padding = 16,
	})
	self.voronoiCanvases = nil
	self.gameOverTimer = nil
	self.levelTimer = 0
	self.lives = Lives.defaultCount()
	local ingame = self
	self.gameHud = GameHud({
		getLives = function()
			return ingame.lives
		end,
		getCoins = function()
			return ingame.coinsCollected
		end,
		getTotal = function()
			return ingame.totalCoins
		end,
		getCameraMode = function()
			return ingame.camera:getMode()
		end,
	})
	self.debugOverlay = DebugOverlay:new()
	self.spriteOverlay = SpriteOutlineOverlay:new()
	self.gridOverlay = GridOverlay:new()

	self.players = spawnPlayers(self, map, 2)
	_G.players = self.players

	initCages(self, map)
	initCoins(self, map)
	EventBus.on("player_died", utils.bindSelf(InGameState.onPlayerDied, self))

	Log.debug(
		"map loaded: "
			.. self.currentMap
			.. " ("
			.. #self.players
			.. " players, "
			.. self.totalCages
			.. " cages, "
			.. self.totalCoins
			.. " coins)"
	)

	if profile then
		profile.stop()
		print("love.load profile:")
		print(profile.report(10))
	end
end

function InGameState:onCageUnlocked(data)
	self.unlockedCages = self.unlockedCages + 1
	Log.debug("Cage unlocked! Total: " .. self.totalCages .. ", Unlocked: " .. self.unlockedCages)

	if self.unlockedCages >= self.totalCages then
		Log.debug("All cages unlocked! Emitting all_cages_unlocked event")
		EventBus.emit("all_cages_unlocked", { totalCages = self.totalCages })
	end
end

function InGameState:onCoinCollected(data)
	self.coinsCollected = self.coinsCollected + 1
end

function InGameState:onPlayerDied(data)
	local result = Lives.applyDeath(self.lives)
	self.lives = result.lives

	if result.outcome == "gameover" then
		self:onGameOver()
	else
		data.player:respawn()
	end
end

function InGameState:onGameOver()
	if self.gameOverTimer then
		return
	end

	self.camera:setMode("gameover")
	self.gameOverTimer = GAME_OVER_ZOOM_DELAY
end

function InGameState:transitionToGameOver()
	local game = self.entity
	game:setGameState("GameOverState")
	game:load({ map = self.currentMap })
end

function InGameState:onPlayerDestroyed(player)
	Log.debug("player destroyed")
	local idx = tbl.findIndexEq(self.players, player)
	table.remove(self.players, idx)

	local playerCount = #self.players
	if playerCount == 0 then
		Log.debug("all players have left the map!")
		local game = self.entity
		game:setGameState("LevelCompleteState")
		game:load({
			map = self.currentMap,
			lives = self.lives,
			maxLives = Lives.defaultCount(),
			coins = self.coinsCollected,
			totalCoins = self.totalCoins,
			time = self.levelTimer,
		})
	end
end

function InGameState:exit()
	EventBus.clear()
end

function InGameState:collectPlayerTargets()
	local targets = {}
	for _, player in ipairs(self.players) do
		local bounds = player.collider:getBounds()
		table.insert(targets, { x = bounds.left, y = bounds.top, w = bounds.width, h = bounds.height })
	end
	return targets
end

function InGameState:updateDeathFramingTargets()
	for _, player in ipairs(self.players) do
		if player:isDead() then
			local bounds = player.collider:getBounds()
			local safePosition = player.safePosition
			self.camera:addExtraTarget(player, {
				x = safePosition.x - bounds.width / 2,
				y = safePosition.y - bounds.height / 2,
				w = bounds.width,
				h = bounds.height,
			})
		else
			self.camera:removeExtraTarget(player)
		end
	end
end

function InGameState:update(dt)
	map:update(dt)
	world:update(dt)
	self.levelTimer = self.levelTimer + dt

	if self.gameOverTimer then
		self.gameOverTimer = self.gameOverTimer - dt
		self.camera:update(dt, self:collectPlayerTargets())
		if self.gameOverTimer <= 0 then
			self:transitionToGameOver()
		end
	else
		self:updateDeathFramingTargets()
		-- The CameraManager always tracks the merged camera + the Voronoi split
		-- state; conf.voronoi only decides whether draw() uses the split
		-- compositing path or the single shared camera.
		self.camera:update(dt, self:collectPlayerTargets())
	end

	self.gameHud:update(dt)

	for i = 1, 4 do
		if inputManager:wasPressed(i, "start") then
			local game = self.entity
			game:setGameState("MenuState")
		end
	end
end

function InGameState:draw()
	-- Voronoi split-screen path (conf.voronoi on + players far apart): render
	-- each player's view into a full-window canvas and composite with the
	-- Voronoi shader. Everything else (incl. the whole game when the toggle is
	-- off) takes the old single auto-zoom camera path.
	local splitActive = conf.voronoi
		and self.camera:isSplit()
		and #self.players >= 2
		and self.camera:getSplitDivergence() >= SPLIT_DIVERGENCE_FLOOR

	if splitActive then
		self:drawVoronoiSplit()
	else
		self:drawMergedView()
	end

	self.gameHud:draw()
end

-- The shared world-draw pipeline (void -> parallax -> tiles -> frame ->
-- entities -> bubbles) for a single view-rect. Used by drawMergedView and,
-- when a `paneRect` ({x,y,w,h} window coords) is supplied, once per player by
-- drawVoronoiSplit — the parallax + diorama render scoped to the pane's
-- sub-rect (via the pane-aware seams) so each player's pane frames its own
-- equal half of the screen.
function InGameState:drawWorldView(vr, paneRect)
	local mapW, mapH = map:getPixelSize()
	Diorama.drawVoid(vr, mapW, mapH, paneRect)
	if paneRect then
		map:drawBackground(vr, self:collectPlayerTargets(), paneRect)
		map:drawMainLayers(vr)
	else
		map:draw2(vr, self:collectPlayerTargets())
	end
	Diorama.drawFrame(vr, mapW, mapH, paneRect)
	map:drawEntities(vr)

	-- screen-space speech bubbles (follow the entity through pan/zoom, but the
	-- text stays readable at any zoom) -- drawn after entities, before the HUD
	for _, story in ipairs(map:getEntitiesByType("story")) do
		story:drawBubbleScreen(vr)
	end
end

-- Old / toggle-off path: one shared auto-zoom camera framing all players, then
-- the debug overlays for that single view.
function InGameState:drawMergedView()
	local vr = self.camera:getDrawParams()
	local mapW, mapH = map:getPixelSize()
	self:drawWorldView(vr)
	self:drawDebugOverlays(vr, mapW, mapH)
end

-- Debug overlays scoped to a single view-rect (physics, sprite outlines, grid).
function InGameState:drawDebugOverlays(vr, mapW, mapH)
	if conf.drawphysics and self.debugOverlay then
		self.debugOverlay.enabled = true
		local targets = self:collectPlayerTargets()
		local cameraFramingBounds = self.camera:computeTargetView(targets)
		self.debugOverlay:draw(world, map, self.players, vr, cameraFramingBounds)
	else
		self.debugOverlay.enabled = false
	end

	-- F3: sprite outlines (drawn after entities, on top of their art)
	if conf.draw_sprite_outlines and self.spriteOverlay then
		self.spriteOverlay.enabled = true
		self.spriteOverlay:draw(map, self.players, vr)
	else
		self.spriteOverlay.enabled = false
	end

	-- F4: world grid overlay
	if conf.draw_grid and self.gridOverlay then
		self.gridOverlay.enabled = true
		self.gridOverlay:draw(mapW, mapH, vr)
	else
		self.gridOverlay.enabled = false
	end
end

-- 0..1 case: how far the split has settled, 0 the moment the dividing line
-- first appears (both canvases still show the merged view -- no jolt) and 1
-- when fully split. Drives both the anchor offsets and the line thickness so
-- the split/join transition is one continuous, aligned glide.
function InGameState:getSplitGrowthBlend()
	local div = self.camera:getSplitDivergence()
	local blend = (div - SPLIT_DIVERGENCE_FLOOR) / SPLIT_FULL_DIVERGENCE
	if blend < 0 then
		return 0
	elseif blend > 1 then
		return 1
	end
	return blend
end

-- Full-window canvases for the Voronoi compositing pass, recreated on resize.
function InGameState:getVoronoiCanvases()
	local lg = love and love.graphics
	if not lg or not lg.newCanvas then
		return nil
	end
	local w, h = lg.getWidth(), lg.getHeight()
	if not self.voronoiCanvases then
		local canvases = { lg.newCanvas(w, h), lg.newCanvas(w, h) }
		self.voronoiCanvases = canvases
	end
	return self.voronoiCanvases
end

-- The Voronoi compositing shader, loaded lazily (headless-safe: nil without love.graphics).
function InGameState:getVoronoiShader()
	local lg = love and love.graphics
	if not lg or not lg.newShader then
		return nil
	end
	if not self.voronoiShader then
		local ok, shader = pcall(lg.newShader, "res/shaders/voronoi_split.glsl")
		if ok and shader then
			self.voronoiShader = shader
		else
			Log.warn("voronoi shader failed to load; using hard-split fallback")
		end
	end
	return self.voronoiShader
end

-- Screen-space UVs of the two players' focal points for the Voronoi shader.
-- Computed from the shared merged view so the bisector moves with player separation.
-- Positional array {u, v} (indices 1,2) per LÖVE 12 Shader:send contract.
function InGameState:computeVoronoiUVs()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local vr = self.camera:getMergedDrawParams()

	local function uv(player)
		local b = player.collider:getBounds()
		local wx = b.left + b.width / 2
		local wy = b.top + b.height / 2
		local px = vr.tx + wx * vr.sx
		local py = vr.ty + wy * vr.sy
		return { px / w, py / h }
	end

	return uv(self.players[1]), uv(self.players[2])
end

-- Voronoi split compositing: render each player's view into a full-window
-- canvas (player centred in full screen, no anchor offsets), then composite
-- with the Voronoi shader's dynamic angled bisector between the players.
function InGameState:drawVoronoiSplit()
	local lg = love and love.graphics
	if not lg then
		return
	end

	local canvases = self:getVoronoiCanvases()
	if not canvases then
		self:drawMergedView()
		return
	end

	local sw, sh = lg.getWidth(), lg.getHeight()
	local zoomBlend = self.camera:getSplitZoomBlend()

	-- Each pane uses full-screen size; no anchor offsets so each player is
	-- centred in their own full-screen canvas. The Voronoi shader then
	-- composites them with a dynamic bisector between the two focal points.
	self.camera:setPaneScreenSize(1, sw, sh)
	self.camera:setPaneScreenSize(2, sw, sh)
	local vr1 = self.camera:getPaneDrawParams(1, 0, 0, zoomBlend)
	local vr2 = self.camera:getPaneDrawParams(2, 0, 0, zoomBlend)

	-- Full-window viewport rect for parallax/diorama scope.
	local fullRect = { x = 0, y = 0, w = sw, h = sh }

	-- Render CanvasA (P1) and CanvasB (P2) as full-screen views.
	local prev = lg.getCanvas()
	lg.setCanvas(canvases[1])
	lg.clear()
	lg.origin()
	self:drawWorldView(vr1, fullRect)
	lg.setCanvas(canvases[2])
	lg.clear()
	lg.origin()
	self:drawWorldView(vr2, fullRect)
	lg.setCanvas(prev)

	-- Composite with Voronoi shader using dynamic player UVs.
	local uv1, uv2 = self:computeVoronoiUVs()
	local shader = self:getVoronoiShader()
	local sf = self.camera:getSplitFactor()
	local lineThickness = VORONOI_LINE_THICKNESS * self:getSplitGrowthBlend()

	lg.push("all")
	lg.setColor(1, 1, 1, 1)

	if shader then
		shader:send("CanvasA", canvases[1])
		shader:send("CanvasB", canvases[2])
		shader:send("p1_screen", uv1)
		shader:send("p2_screen", uv2)
		shader:send("split_factor", sf)
		shader:send("line_thickness", lineThickness)
		shader:send("line_color", VORONOI_LINE_COLOR)
		lg.setShader(shader)
		lg.draw(canvases[1], 0, 0)
		lg.setShader()
	else
		-- Fallback: hard vertical split at screen centre.
		lg.draw(canvases[1], 0, 0)
		if lg.setScissor then
			lg.setScissor(sw / 2, 0, sw / 2, sh)
			lg.draw(canvases[2], 0, 0)
			lg.setScissor()
		else
			lg.draw(canvases[2], 0, 0)
		end
	end

	lg.pop()
	lg.setColor(1, 1, 1, 1)
end

function InGameState:resize(w, h)
	if map then
		map:resize(w, h)
	end

	if self.camera then
		self.camera:setScreenSize(w, h)
		local mapW, mapH = map:getPixelSize()
		self.camera:setMapSize(mapW, mapH)
	end

	-- Drop the Voronoi pane canvases so they recreate at the new size.
	self.voronoiCanvases = nil
end

function InGameState:keypressed(k)
	local game = self.entity
	if k == "escape" then
		game:setGameState("MenuState")
	elseif k == "space" then
		self.camera:toggleOverview()
	end
end

local BACK_BUTTONS = { back = true, select = true, guide = true }

function InGameState:gamepadpressed(joystick, button)
	if BACK_BUTTONS[button] then
		self.camera:toggleOverview()
	end
end

return InGameState
