-- Proves the patched STI resolves an external (.tsj-referenced) tileset
-- through the real Map/STI stack, not just the pure external_tileset
-- module in isolation.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")

test(
	"a map referencing an external tileset loads, resolves the tileset shape, and steps frames without error",
	function()
		local game = GameHarness.startGame("tests/fixtures/external_tileset_room.tmj")

		-- `map` is the global set by src/game_states.lua's InGameState:load;
		-- read it immediately, before any other test can overwrite it.
		local stiMap = map.map
		local tileset = stiMap.tilesets[1]

		assertTrue(tileset.image ~= nil, "expected the external tileset to resolve an image")
		assertEqual(256, tileset.imagewidth)
		assertEqual(576, tileset.imageheight)
		assertEqual(32, tileset.tilewidth)
		assertEqual(32, tileset.tileheight)
		assertEqual(8, tileset.columns)
		assertEqual(144, tileset.tilecount)

		FrameStepper.step(game, 5)

		local ingame = game.fsm.currentState
		assertTrue(#ingame.players > 0, "expected at least one player to have spawned")
	end
)

test("per-tile custom properties on an external tileset are readable via Map:getTileProperties", function()
	GameHarness.startGame("tests/fixtures/external_tileset_room.tmj")

	-- Bottom row (y=3) of the "ground" layer is gid 1 (tile id 0), which
	-- carries a "solid" property in external_tileset_room.tsj.
	local properties = map:getTileProperties("ground", 1, 3)

	assertEqual(true, properties["solid"])
end)

test("per-tile animation frames on an external tileset animate the same way embedded-tileset ones do", function()
	GameHarness.startGame("tests/fixtures/external_tileset_room.tmj")

	-- gid 2 (tile id 1) carries a two-frame, 50ms-per-frame animation in
	-- external_tileset_room.tsj.
	local animatedTile = map.map.tiles[2]
	assertEqual(1, animatedTile.frame)

	local dt = 1 / 60
	for _ = 1, 4 do -- ~66.7ms, > one 50ms frame
		map.map:update(dt)
	end

	assertEqual(2, animatedTile.frame)
end)

test(
	"a map referencing an external single-tile tileset resolves cropped tile images and steps frames without error",
	function()
		local game = GameHarness.startGame("tests/fixtures/external_tileset_collection_room.tmj")

		local stiMap = map.map
		local tileset = stiMap.tilesets[1]

		assertEqual(1, #tileset.tiles)

		local switchTile = nil
		for _, tile in ipairs(tileset.tiles) do
			if tile.id == 0 then
				switchTile = tile
			end
		end

		assertTrue(switchTile ~= nil, "expected to find the switch tile (id 0) in the resolved tileset")
		assertEqual("res/img/entity_switch.png", switchTile.image)

		FrameStepper.step(game, 5)

		local ingame = game.fsm.currentState
		assertTrue(#ingame.players > 0, "expected at least one player to have spawned")
	end
)

test("a missing external tileset file fails loudly at map-load time", function()
	local ok, err = pcall(function()
		GameHarness.startGame("tests/fixtures/external_tileset_missing_room.tmj")
	end)

	assertEqual(false, ok)
end)
