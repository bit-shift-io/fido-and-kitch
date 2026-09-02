-- A switch's `startOn` property lets a level designer place it already on
-- when the map loads. Unlike a player-triggered toggle, no animation plays
-- and no sound is triggered -- the switch simply appears in its 'on' pose.
-- Driven through the real Game/Map/World stack on
-- tests/fixtures/switch_start_on_room.tmj (a copy of switch_room.tmj with
-- startOn=true added to switch1).
local GameHarness = require('tests.support.game_harness')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/switch_start_on_room.tmj'

test('a switch with startOn=true loads already on, snapped to its end pose', function()
	-- boot globals via a throwaway game first so SoundSpy (which requires
	-- src.components.sound, only defined once globals are booted) can be
	-- installed BEFORE the real map loads -- the only way to observe
	-- whether the switch itself plays a sound at construction time.
	GameHarness.startGame('tests/fixtures/switch_room.tmj')
	local spy = SoundSpy.install()
	local game = GameHarness.startGame(MAP)

	local switch = Queries.findEntityByName(map, 'switch1')
	local sprite = switch.sprite

	assertEqual('on', switch.state)
	assertFalse(sprite:isPlaying(), 'should appear already on, not mid-animation')
	assertEqual(5, sprite.frameNum, 'should rest on the last frame, same as after a completed forward play')
	assertEqual(0, #spy.played, 'no toggle sound should play on load')

	spy.uninstall()
end)

test('a switch with startOn=true is ready to play the reverse animation when first used', function()
	local game = GameHarness.startGame(MAP)

	local switch = Queries.findEntityByName(map, 'switch1')
	local sprite = switch.sprite

	assertEqual('reverse', sprite:getDirection())
end)
