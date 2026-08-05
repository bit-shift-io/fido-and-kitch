# Per-Level Coin Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make coin collection meaningful. Coins currently just play a sound, spawn a sparkle, and add an inventory entry under an arbitrary Tiled object name (`coin1`, `coin2`, …). This plan adds per-level coin tracking: a `coin_collected` EventBus event, an `X/Y coins collected` report at level end, and a unified fading game HUD (hearts + coin counter). Keys keep their `key_<color>` names and never match `'coin'`.

**Architecture:** A constant `'coin'` itemName on the coin pickup feeds a guarded emit in `Player:pickup` that fires `coin_collected` with a `{x, y}` payload. `InGameState` mirrors its existing `cage_unlocked` pattern to count total coins at load and collected coins per level, and logs the final `X/Y` report when the last player leaves the map (the exit door path — the end of the level). A new `GameHud` class (a `LivesHud` plus a coin counter behind one shared alpha, using the existing ambient-`setColor` fade idiom from `FlashEffect`) replaces the bare `livesHud:draw()` in `InGameState:draw`. `player_died` is upgraded to a table payload so all three event shapes are uniform.

**Tech Stack:** LÖVE 12.0 (LuaJIT), bump.lua physics, hump.Class, STI for Tiled maps, existing component/entity system, `src/utils/event_bus.lua`, `src/ui/lives_hud.lua`, `src/components/flash_effect.lua`.

## Global Constraints

- Follow existing code conventions: globals intentional, hump.Class with `Class{}`, `Entity.init(self)` in `init`, components via `addComponent()`
- **Alpha is drawn, not stored on sprites:** neither `Sprite` nor a new component gains an alpha field. `GameHud:draw()` sets `love.graphics.setColor(1, 1, 1, alpha)` around the hearts, coin icon, and text, exactly like `FlashEffect:draw`/`postDraw` and `Player:draw`. **Wrinkle:** `LivesHud:draw` ends by resetting the colour to `(1,1,1,1)` (src/ui/lives_hud.lua:37), so `GameHud:draw` must re-apply its alpha after drawing the hearts and before drawing the coin counter.
- `player_died` currently emits positionally (`EventBus.emit('player_died', self, self.deathType)`); this plan upgrades it to a `{player, deathType}` table so it matches `cage_unlocked` / `coin_collected`. Verified touchpoints (and the only ones): `src/player/player.lua:232` (emit), `src/states/ingame_state.lua:88` (subscribe) and `:107` (handler). No tests reference `player_died`.
- The end-of-level report fires when the last player is destroyed (`InGameState:onPlayerDestroyed`, player count hits 0). The exit door is the only thing that destroys players in normal play (its `ExitDoor:checkEndGame()` is an empty stub; game over never destroys players), so this path IS the exit-door level end.
- Coin counter renders only once coins have been collected (`getCoins() > 0`); it never shows `0/0`.
- Test tiers: `./test-unit.sh <file>` (headless logic; new unit files MUST be registered in `tests/unit/run.lua`'s `defaultTestFiles`), `./test-integration.sh <file>` (real map stack via GameHarness), `./test-e2e.sh` (real LÖVE window; not required by this design)
- `love.graphics.print` does NOT exist in `tests/support/love_mock.lua`; the GameHud task extends the mock with a no-op `print` (per the mock's documented philosophy: extend it when a mechanic touches a new love call)
- Keep changes small; match nearby style (mixed quotes/indentation); `git add` only the files each task names

---

### Task 1: Constant Coin Item Name (`src/entities/coin.lua`)

**Files:**
- Modify: `src/entities/coin.lua`
- Create: `tests/unit/coin_identity_test.lua`
- Modify: `tests/unit/run.lua` (register the new test file)

**Interfaces:**
- Consumes: `tests/support/headless_bootstrap.lua` (wires the `Class`/`Entity`/`Sprite`/`Collider`/`Sound`/`Rect`/`Vector` globals a coin entity needs; `resetWorld()` provides a fresh `world`), `src/components/pickup.lua` (the `Pickup` component that carries `itemName` — the unit tier has no `Pickup` global, so the test wires it)
- Produces: coin entities whose `Pickup` component always reports `itemName == 'coin'`, regardless of the Tiled object's `name`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/coin_identity_test.lua
-- A coin must grant the constant item name 'coin', not the arbitrary Tiled
-- object name. Constructs a real Coin through headless_bootstrap (ADR 0005)
-- and inspects its Pickup component. HeadlessBootstrap.resetWorld() gives a
-- fresh `world`; the unit tier has no Pickup global, so it is wired here
-- (the same `X = X or require(...)` idiom the bootstrap itself uses).
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
HeadlessBootstrap.resetWorld()

Pickup = Pickup or require('src.components.pickup')

local Coin = require('src.entities.coin')

local function makeCoin(name)
	return Coin{
		name = name,
		x = 100,
		y = 100,
		width = 20,
		height = 20,
		properties = {},
	}
end

test('a coin grants the constant itemName "coin" regardless of its Tiled object name', function()
	local coin = makeCoin('a-random-tiled-name')
	local pickup = coin:getComponent(Pickup)
	assertEqual('coin', pickup.itemName, 'expected the constant "coin", got the Tiled object name')
end)

test('a coin still records its own Tiled name on the entity', function()
	local coin = makeCoin('coin-b')
	assertEqual('coin-b', coin.name, 'entity name should still come from the Tiled object')
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-unit.sh tests/unit/coin_identity_test.lua`
Expected: FAIL — `pickup.itemName` is `'a-random-tiled-name'`, not `'coin'`

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/entities/coin.lua (change the itemName line only)
	itemName = function(object) return 'coin' end,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-unit.sh tests/unit/coin_identity_test.lua`
Expected: PASS (both tests)

Register the file in `tests/unit/run.lua`'s `defaultTestFiles` list (append `'tests/unit/coin_identity_test.lua',`).

Run: `./test-unit.sh`
Expected: PASS (full unit suite)

- [ ] **Step 5: Commit**

```bash
git add src/entities/coin.lua tests/unit/coin_identity_test.lua tests/unit/run.lua
git commit -m "feat(coin): give coins a constant itemName 'coin'"
```

---

### Task 2: Emit `coin_collected` on Pickup (`src/player/player.lua`)

**Files:**
- Modify: `src/player/player.lua`
- Create: `tests/integration/coin_tracking_test.lua`

**Interfaces:**
- Consumes: `src/utils/event_bus.lua` (lazily required, matching the existing lazy `require('src.utils.event_bus')` inside `Player:resolveDeath`), `tests/support/game_harness.lua`, `tests/support/fake_input.lua`, `tests/support/frame_stepper.lua`, `tests/fixtures/coin_room.lua`
- Produces: `coin_collected` EventBus events with a `{x, y}` payload (the coin's centre, from `pickup.entity.sprite.position` — the `Collider` syncs the sprite to its centre each frame)

Data flow (verified): Tiled coin → `Pickup:contact` (src/components/pickup.lua:22) → `Player:pickup` (src/player/player.lua:273) → sound + `inventory:addItems` + NEW emit → `entity:queueDestroy()`. The emit fires before the destroy.

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/coin_tracking_test.lua
-- Walks P1 onto the single coin in coin_room (spawn 64,128 32x32; coin at
-- 120,160 20x20, centre 130,170) and asserts the coin_collected event fires
-- with the coin position and that the coin is in the inventory under the
-- constant name 'coin' (Task 1).
local GameHarness = require('tests.support.game_harness')
local FakeInput = require('tests.support.fake_input').FakeInput
local FrameStepper = require('tests.support.frame_stepper')
local EventBus = require('src.utils.event_bus')

local MAP = 'tests/fixtures/coin_room.lua'

test('walking onto a coin emits coin_collected with the coin position', function()
	local game = GameHarness.startGame(MAP)
	local state = game.fsm.currentState
	local controller = FakeInput.new()

	local collected = {}
	local disconnect = EventBus.on('coin_collected', function(data)
		table.insert(collected, data)
	end)

	controller:press('right')
	FrameStepper.step(game, 180)
	controller:release('right')

	disconnect()

	assertEqual(1, #collected, 'expected exactly one coin_collected event')
	assertEqual(130, collected[1].x, 'event should carry the coin centre x')
	assertEqual(170, collected[1].y, 'event should carry the coin centre y')
	assertTrue(state.players[1].inventory:hasItems('coin', 1), 'the coin should be in the player inventory under the constant name')
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/coin_tracking_test.lua`
Expected: FAIL — `#collected == 0` (no event is emitted yet)

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/player/player.lua — extend Player:pickup (currently ends at entity:queueDestroy())
function Player:pickup(pickup)
    local entity = pickup.entity
    Log.debug('player picked up a ' .. pickup.itemName)
    local sound = entity:getComponent(Sound)
    if sound ~= nil then
        sound:play('pickup')
    end
    self.inventory:addItems(pickup.itemName, pickup.itemCount)

    if pickup.itemName == 'coin' then
        local EventBus = require('src.utils.event_bus')
        EventBus.emit('coin_collected', {x = entity.sprite.position.x, y = entity.sprite.position.y})
    end

    entity:queueDestroy()
end
```

Keys keep `key_<color>` and never match `'coin'`, so they never fire this event.

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/coin_tracking_test.lua`
Expected: PASS. Also run `./test-integration.sh` (full suite) and `./test-unit.sh` — no regressions.

- [ ] **Step 5: Commit**

```bash
git add src/player/player.lua tests/integration/coin_tracking_test.lua
git commit -m "feat(coin): emit coin_collected event on pickup"
```

---

### Task 3: InGameState Coin Counter and Level-End Report (`src/states/ingame_state.lua`)

**Files:**
- Modify: `src/states/ingame_state.lua`
- Modify: `tests/integration/coin_tracking_test.lua` (add an assertion test)
- Create: `tests/unit/ingame_coin_report_test.lua`
- Modify: `tests/unit/run.lua` (register the new unit file)

**Interfaces:**
- Consumes: `Map:getEntitiesByType('coin')` (src/map/init.lua:184), `EventBus.on('coin_collected', ...)`, `Lives` (unchanged), `src/utils/log.lua` (`Log.info` prints at the default level)
- Produces: `InGameState.totalCoins` (level coin count, set in `load`), `InGameState.coinsCollected` (reset to 0 each load), `InGameState:onCoinCollected(data)` (increments), and a `Log.info('Level complete: X/Y coins collected')` line when the last player leaves the map

- [ ] **Step 1: Write the failing test**

Add to `tests/integration/coin_tracking_test.lua`:

```lua
test('InGameState counts the level total and increments on collection', function()
	local game = GameHarness.startGame(MAP)
	local state = game.fsm.currentState
	local controller = FakeInput.new()

	assertEqual(1, state.totalCoins, 'fixture has a single coin')
	assertEqual(0, state.coinsCollected, 'no coins collected yet')

	controller:press('right')
	FrameStepper.step(game, 180)
	controller:release('right')

	assertEqual(1, state.coinsCollected, 'coin collection should be counted')
end)
```

Create `tests/unit/ingame_coin_report_test.lua` (the log line isn't assertable in the integration tier, so the report is unit-tested by driving `InGameState:onPlayerDestroyed` directly, mirroring `tests/unit/ingame_cage_tracking.unit.test.lua`):

```lua
-- tests/unit/ingame_coin_report_test.lua
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local Log = require('src.utils.log')

local InGameState = require('src.states.ingame_state')

local function makeState(coinsCollected, totalCoins)
	local state = InGameState{}
	state.players = {{}, {}}
	state.coinsCollected = coinsCollected
	state.totalCoins = totalCoins
	state.entity = {
		setGameState = function() end,
	}
	return state
end

local function destroyAll(state)
	local reported = nil
	local origInfo = Log.info
	Log.info = function(...)
		reported = {n = select('#', ...), ...}
	end
	state:onPlayerDestroyed(state.players[1])
	state:onPlayerDestroyed(state.players[2])
	Log.info = origInfo
	return reported
end

test('when the last player leaves the map a coin report is logged', function()
	local state = makeState(1, 3)
	local reported = destroyAll(state)
	assertTrue(reported ~= nil, 'expected a coin report log line')
	local line = table.concat(reported, ' ')
	assertTrue(line:find('1/3') ~= nil, 'expected the report to show 1/3, got: ' .. line)
end)

test('a zero-coin level still reports safely as 0/0', function()
	local state = makeState(0, 0)
	local reported = destroyAll(state)
	assertTrue(reported ~= nil, 'expected a 0/0 report to still be logged')
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./test-unit.sh tests/unit/ingame_coin_report_test.lua`
Expected: FAIL — no report is logged yet (no `Log.info` in `onPlayerDestroyed`)

Run: `./test-integration.sh tests/integration/coin_tracking_test.lua`
Expected: FAIL — `state.totalCoins` is `nil`

- [ ] **Step 3: Write minimal implementation**

In `InGameState:load`, after the cage-count block and before the `cage_unlocked` subscribe (mirrors the cage pattern exactly):

```lua
    -- Count total coins in level and listen for collection
    self.totalCoins = #map:getEntitiesByType('coin')
    self.coinsCollected = 0
    self.coinCollectedHandler = EventBus.on('coin_collected', utils.bindSelf(InGameState.onCoinCollected, self))
```

Add the handler (near `onCageUnlocked`):

```lua
function InGameState:onCoinCollected(data)
    self.coinsCollected = self.coinsCollected + 1
end
```

Report in `onPlayerDestroyed` (the `playerCount == 0` branch):

```lua
    if playerCount == 0 then
        Log.info(string.format('Level complete: %d/%d coins collected', self.coinsCollected, self.totalCoins))
        Log.debug('all players have left the map!')
        local game = self.entity
        game:setGameState('MenuState')
    end
```

Unsubscription is already handled by the existing `EventBus.clear()` in `InGameState:exit()` (src/states/ingame_state.lua:147).

- [ ] **Step 4: Run tests to verify they pass**

Run: `./test-unit.sh tests/unit/ingame_coin_report_test.lua`
Expected: PASS. Run: `./test-integration.sh tests/integration/coin_tracking_test.lua` — PASS. Register `'tests/unit/ingame_coin_report_test.lua',` in `tests/unit/run.lua` and run the full `./test-unit.sh` + `./test-integration.sh`.

- [ ] **Step 5: Commit**

```bash
git add src/states/ingame_state.lua tests/integration/coin_tracking_test.lua tests/unit/ingame_coin_report_test.lua tests/unit/run.lua
git commit -m "feat(coin): track per-level coin totals and collection"
```

---

### Task 4: Uniform `player_died` Table Payload

**Files:**
- Modify: `src/player/player.lua`
- Modify: `src/states/ingame_state.lua`
- Create: `tests/integration/player_died_payload_test.lua`

**Interfaces:**
- Consumes: `src/utils/event_bus.lua`, `tests/fixtures/kill_zone_room.lua` (spawn at 64,128; a `kill_zone` with `deathType = "water"` spanning the floor)
- Produces: `player_died` events with a `{player = self, deathType = self.deathType}` table payload, and `InGameState:onPlayerDied(data)` reading `data.player` / `data.deathType` — making `player_died` the same shape as `cage_unlocked` and `coin_collected`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/integration/player_died_payload_test.lua
-- Falls P1 into the water kill zone and asserts player_died carries a table
-- payload. `>= 1` rather than a fixed count: the player falls repeatedly and
-- the spawn flash guards further deaths, but the exact count is not the
-- contract — the payload shape is.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local EventBus = require('src.utils.event_bus')

local MAP = 'tests/fixtures/kill_zone_room.lua'

test('player_died carries a table payload with player and deathType', function()
	local game = GameHarness.startGame(MAP)

	local payloads = {}
	local disconnect = EventBus.on('player_died', function(data)
		table.insert(payloads, data)
	end)

	FrameStepper.step(game, 90)

	disconnect()

	assertTrue(#payloads >= 1, 'expected at least one player death in 90 frames')
	local data = payloads[1]
	assertTrue(type(data) == 'table', 'player_died payload should be a table')
	assertTrue(data.player ~= nil, 'payload should carry the player')
	assertTrue(data.deathType ~= nil, 'payload should carry the deathType')
	assertEqual('water', data.deathType, 'payload should carry the kill zone deathType')
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-integration.sh tests/integration/player_died_payload_test.lua`
Expected: FAIL — the old positional emit makes `data` the player entity, so `data.player` and `data.deathType` are `nil`

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/player/player.lua — Player:resolveDeath
function Player:resolveDeath()
    local EventBus = require('src.utils.event_bus')
    EventBus.emit('player_died', {player = self, deathType = self.deathType})
end
```

```lua
-- src/states/ingame_state.lua — InGameState:onPlayerDied
function InGameState:onPlayerDied(data)
    local result = Lives.applyDeath(self.lives)
    self.lives = result.lives

    if result.outcome == 'gameover' then
        self:onGameOver()
    else
        data.player:respawn()
    end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-integration.sh tests/integration/player_died_payload_test.lua`
Expected: PASS. Run the full `./test-integration.sh` (kill-zone sound, lives flows) and `./test-unit.sh` — no regressions.

- [ ] **Step 5: Commit**

```bash
git add src/player/player.lua src/states/ingame_state.lua tests/integration/player_died_payload_test.lua
git commit -m "refactor(player): emit player_died with a table payload"
```

---

### Task 5: Fading GameHud (`src/ui/game_hud.lua`)

**Files:**
- Create: `src/ui/game_hud.lua`
- Modify: `src/states/ingame_state.lua` (construct `gameHud`, drive `gameHud:update(dt)`, draw it)
- Modify: `tests/support/love_mock.lua` (add a no-op `print` to `love.graphics`)
- Create: `tests/unit/game_hud_test.lua`
- Modify: `tests/unit/run.lua` (register the new unit file)

**Interfaces:**
- Consumes: `src/ui/lives_hud.lua` (owns the hearts), `src/components/sprite.lua` (coin icon), `src/utils/event_bus.lua`, `src/utils/utils.lua` (`bindSelf`), global `Class`/`Vector`/`Sprite` (same globals `lives_hud.lua` uses), and callback props `getLives`, `getCoins`, `getTotal`, `getCameraMode`
- Produces: `GameHud` with a shared `alpha` behind a small fade state machine (hidden during follow, fully opaque in overview/gameover, fades in on `coin_collected`/`player_died`, holds ~2s, fades out), and the coin counter (`res/img/ui_coin.png`, 128x128 like `ui_heart.png`) drawn only when `getCoins() > 0`

Behavior spec:
- Follow mode, no trigger → `alpha` stays 0 (hidden)
- Overview / gameover mode → `alpha` forced to 1; on returning to follow it drifts back out
- `coin_collected` or `player_died` → fade in to 1 over 1.2s (`0.15 * 8`, the same duration as the player spawn flash), hold 2.0s, fade back out over 1.2s
- Coin counter renders only when `getCoins() > 0` (never `0/0`)

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/game_hud_test.lua
-- Headless alpha-state machine coverage for GameHud. love stays nil unless a
-- test needs it (draw smoke); the draw test installs LoveMock.new(), and the
-- mock needs a no-op love.graphics.print (added below). EventBus signals
-- persist across tests in one process, so each test clears them first.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local LoveMock = require('tests.support.love_mock')
local EventBus = require('src.utils.event_bus')

local GameHud = require('src.ui.game_hud')

local FADE_FRAMES = 72   -- 1.2s at 1/60
local HOLD_FRAMES = 120  -- 2.0s at 1/60

local function makeHud()
	local mode = 'follow'
	local hud = GameHud{
		getLives = function() return 3 end,
		getCoins = function() return 1 end,
		getTotal = function() return 3 end,
		getCameraMode = function() return mode end,
		livesHud = {draw = function() end},
	}
	local function setMode(next)
		mode = next
	end
	return hud, setMode
end

local function step(hud, frames)
	for _ = 1, frames do
		hud:update(1 / 60)
	end
end

test('the HUD stays hidden in follow mode', function()
	EventBus.clear()
	local hud = makeHud()
	step(hud, 120)
	assertEqual(0, hud.alpha, 'expected alpha 0 in follow mode')
end)

test('the HUD is fully opaque in overview mode', function()
	EventBus.clear()
	local hud, setMode = makeHud()
	setMode('overview')
	step(hud, 1)
	assertEqual(1, hud.alpha, 'expected alpha 1 in overview mode')
end)

test('a coin pickup fades the HUD in, holds, then fades back out', function()
	EventBus.clear()
	local hud = makeHud()

	EventBus.emit('coin_collected', {x = 130, y = 170})
	step(hud, FADE_FRAMES)
	assertEqual(1, hud.alpha, 'expected the HUD to reach full opacity after a pickup')

	step(hud, HOLD_FRAMES - FADE_FRAMES)
	assertEqual(1, hud.alpha, 'expected the HUD to hold while the timer runs')

	step(hud, FADE_FRAMES)
	assertEqual(0, hud.alpha, 'expected the HUD to fade back out')
end)

test('a life lost also fades the HUD in', function()
	EventBus.clear()
	local hud = makeHud()

	EventBus.emit('player_died', {player = {}, deathType = 'water'})
	step(hud, FADE_FRAMES)
	assertEqual(1, hud.alpha, 'expected player_died to fade the HUD in')
end)

test('drawing with coins collected renders under the love mock', function()
	EventBus.clear()
	love = LoveMock.new()
	local hud = makeHud()

	EventBus.emit('coin_collected', {x = 130, y = 170})
	step(hud, FADE_FRAMES)
	assertEqual(1, hud.alpha, 'expected full opacity before drawing')
	hud:draw()
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test-unit.sh tests/unit/game_hud_test.lua`
Expected: FAIL — `module 'src.ui.game_hud' not found`

- [ ] **Step 3: Write minimal implementation**

```lua
-- src/ui/game_hud.lua
-- Unifies the hearts (a LivesHud) and the per-level coin counter behind one
-- shared fade alpha. Alpha is applied the FlashEffect way -- the ambient
-- love.graphics colour around each drawn piece -- not as a Sprite field.
local Sprite = require('src.components.sprite')
local LivesHud = require('src.ui.lives_hud')
local EventBus = require('src.utils.event_bus')
local utils = require('src.utils.utils')

local GameHud = Class{}

-- Heart geometry mirrors LivesHud's locals (24/8/16) so the coin counter
-- can sit immediately right of the last heart.
local HEART_SIZE = 24
local HEART_SPACING = 8
local ICON_SIZE = 24
local MARGIN = 16
local TEXT_SPACING = 6
local TEXT_Y_OFFSET = 6
local FADE_DURATION = 0.15 * 8 -- 1.2s, same as the player spawn flash
local HOLD_DURATION = 2.0

function GameHud:init(props)
	self.getLives = props.getLives
	self.getCoins = props.getCoins
	self.getTotal = props.getTotal
	self.getCameraMode = props.getCameraMode

	self.livesHud = props.livesHud or LivesHud{getLives = self.getLives}

	self.alpha = 0
	self._fadeIn = false
	self._fadeInElapsed = 0
	self._fadeOut = false
	self._fadeOutElapsed = 0
	self.holdTimer = 0
	self.coinIcon = nil

	-- Cleared along with everything else by InGameState:exit() -> EventBus.clear()
	EventBus.on('coin_collected', utils.bindSelf(self._onTrigger, self))
	EventBus.on('player_died', utils.bindSelf(self._onTrigger, self))
end

function GameHud:_onTrigger()
	self.holdTimer = HOLD_DURATION
	if self._fadeOut then
		-- reverse a fade-out from wherever it currently is
		self._fadeOut = false
		self._fadeIn = true
		self._fadeInElapsed = (1 - self.alpha) * FADE_DURATION
	elseif not self._fadeIn and self.alpha < 1 then
		self._fadeIn = true
		self._fadeInElapsed = (1 - self.alpha) * FADE_DURATION
	end
end

function GameHud:update(dt)
	local mode = self.getCameraMode()
	if mode == 'overview' or mode == 'gameover' then
		self._fadeIn = false
		self._fadeOut = false
		self.holdTimer = 0
		self.alpha = 1
		return
	end

	if self._fadeIn then
		self._fadeInElapsed = self._fadeInElapsed + dt
		self.alpha = math.min(1, self._fadeInElapsed / FADE_DURATION)
		if self.alpha >= 1 then
			self._fadeIn = false
		end
	end

	if self.holdTimer > 0 then
		self.holdTimer = self.holdTimer - dt
		if self.holdTimer <= 0 and self.alpha > 0 then
			self._fadeOut = true
			self._fadeOutElapsed = 0
		end
		return
	end

	if self._fadeOut then
		self._fadeOutElapsed = self._fadeOutElapsed + dt
		self.alpha = math.max(0, 1 - self._fadeOutElapsed / FADE_DURATION)
		if self.alpha <= 0 then
			self._fadeOut = false
		end
	elseif self.alpha > 0 then
		-- just left overview/gameover with a full-opacity HUD: drift back out
		self._fadeOut = true
		self._fadeOutElapsed = 0
	end
end

function GameHud:draw()
	if self.alpha <= 0 then
		return
	end

	love.graphics.setColor(1, 1, 1, self.alpha)
	self.livesHud:draw()

	local coins = self.getCoins()
	if coins > 0 then
		-- LivesHud:draw() reset the colour to (1,1,1,1); re-apply the fade
		love.graphics.setColor(1, 1, 1, self.alpha)

		local x = MARGIN + self.getLives() * (HEART_SIZE + HEART_SPACING)
		local icon = self.coinIcon
		if not icon then
			icon = Sprite{
				frames = {'res/img/ui_coin.png'},
				position = Vector(x, MARGIN),
				scale = Vector(ICON_SIZE / 128, ICON_SIZE / 128),
			}
			self.coinIcon = icon
		end
		icon.position = Vector(x, MARGIN)
		icon:draw()

		love.graphics.print(string.format('%d/%d', coins, self.getTotal()), x + ICON_SIZE + TEXT_SPACING, MARGIN + TEXT_Y_OFFSET)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return GameHud
```

Add a no-op `print` to the mock's `love.graphics` table (after `getColor`):

```lua
		print = function() end,
```

Wire the state (in `src/states/ingame_state.lua`):

```lua
-- top of file: replace the LivesHud require
local GameHud = require('src.ui.game_hud')

-- InGameState:load, replacing the current self.livesHud construction:
	self.lives = Lives.defaultCount()
	local ingame = self
	self.gameHud = GameHud{
		getLives = function() return ingame.lives end,
		getCoins = function() return ingame.coinsCollected end,
		getTotal = function() return ingame.totalCoins end,
		getCameraMode = function() return ingame.camera:getMode() end,
	}

-- InGameState:update(dt), after the camera update and before the input loop:
	self.gameHud:update(dt)

-- InGameState:draw(), replacing self.livesHud:draw():
	self.gameHud:draw()
```

(Requires Task 3's `coinsCollected`/`totalCoins`, already in `load`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `./test-unit.sh tests/unit/game_hud_test.lua`
Expected: PASS (all 5 tests). Register `'tests/unit/game_hud_test.lua',` in `tests/unit/run.lua` and run the full `./test-unit.sh` and `./test-integration.sh`.

- [ ] **Step 5: Commit**

```bash
git add src/ui/game_hud.lua src/states/ingame_state.lua tests/support/love_mock.lua tests/unit/game_hud_test.lua tests/unit/run.lua
git commit -m "feat(ui): add fading GameHud with hearts and coin counter"
```

---

## Execution Summary

**Total Tasks:** 5
- Task 1: Constant `'coin'` itemName (unit)
- Task 2: `coin_collected` emission (integration)
- Task 3: InGameState counter + level-end report (integration + unit)
- Task 4: Uniform `player_died` table payload (integration)
- Task 5: Fading GameHud + state wiring (unit, love mock)

**Estimated Time:** ~half a day for full implementation

**Test Commands:**
- Unit: `./test-unit.sh tests/unit/coin_identity_test.lua`, `./test-unit.sh tests/unit/ingame_coin_report_test.lua`, `./test-unit.sh tests/unit/game_hud_test.lua`
- Integration: `./test-integration.sh tests/integration/coin_tracking_test.lua`, `./test-integration.sh tests/integration/player_died_payload_test.lua`
- All: `./test-all.sh`

**Design decisions carried in from `docs/superpowers/specs/2026-08-05-coin-tracking-design.md` (and the follow-up decisions):**
- Alpha is drawn via ambient `setColor` (the `FlashEffect` idiom), not a Sprite field or a new transparency component
- `player_died` upgraded to a `{player, deathType}` table so all event payloads are uniform
- HUD hidden during follow, opaque in overview/gameover, fades in on coin pickup or life lost, holds ~2s, fades out
- Coin counter hidden until the first coin is collected (never `0/0`)
- Report fires on exit-door level end (last player destroyed), log only
- Coin x/y captured before `queueDestroy()`

---

**Plan complete and saved to `docs/superpowers/plans/2026-08-05-coin-tracking-design.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
