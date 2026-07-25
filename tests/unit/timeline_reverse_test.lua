-- Unit tests for the reversible Timeline playback API: forward, reverse,
-- mid-playback reverse, dual-end finish signal, and frame-index correctness.
Class = Class or require('lib.hump.class')
tbl = tbl or require('src.utils.tbl')
Signal = Signal or require('src.utils.signal')
Tween = Tween or require('lib.tween.tween')
local Timeline = require('src.components.timeline')

test('forward play to the end fires finish exactly once and lands on the last frame', function()
	local finishCount = 0
	local timeline = Timeline{duration = 1.0, finish = function() finishCount = finishCount + 1 end}
	timeline:playForward()

	timeline:update(1.2) -- overshoot past the end

	assertEqual(1, finishCount)
	assertEqual(4, timeline:getFrameIndex(4))
	assertFalse(timeline.playing)
end)

test('reverse play from the end fires finish exactly once and lands on the first frame', function()
	local finishCount = 0
	local timeline = Timeline{duration = 1.0, finish = function() finishCount = finishCount + 1 end}
	timeline:playReverse()

	timeline:update(1.2) -- overshoot past the start

	assertEqual(1, finishCount)
	assertEqual(1, timeline:getFrameIndex(4))
	assertFalse(timeline.playing)
end)

test('reversing mid-playback flips direction and moves the opposite way on the next step', function()
	local timeline = Timeline{duration = 1.0}
	timeline:playForward()
	timeline:update(0.4) -- time = 0.4, still mid-flight forward

	timeline:reverseFromCurrent()
	assertEqual('reverse', timeline:getDirection())

	timeline:update(0.1)
	assertNear(0.3, timeline:timePercent(), 0.0001)
end)

test('frame index is in-bounds and correct at both extremes across a range of frame counts', function()
	for _, frameCount in ipairs({2, 3, 5, 8}) do
		local timeline = Timeline{duration = 1.0}

		timeline:playForward()
		assertEqual(1, timeline:getFrameIndex(frameCount))

		timeline:update(1.0)
		assertEqual(frameCount, timeline:getFrameIndex(frameCount))

		timeline:playReverse()
		assertEqual(frameCount, timeline:getFrameIndex(frameCount))

		timeline:update(1.0)
		assertEqual(1, timeline:getFrameIndex(frameCount))
	end
end)

test('a forward-only timeline with no reverse calls behaves exactly as before', function()
	local finishCount = 0
	local timeline = Timeline{duration = 1.0, finish = function() finishCount = finishCount + 1 end}
	timeline:reset()
	timeline:play()

	timeline:update(0.5)
	assertEqual(0, finishCount)
	assertTrue(timeline.playing)

	timeline:update(0.5)
	assertEqual(1, finishCount)
	assertFalse(timeline.playing)
end)

test('speed is queryable and settable', function()
	local timeline = Timeline{duration = 1.0}
	assertEqual(1, timeline:getSpeed())

	timeline:setSpeed(2)
	assertEqual(2, timeline:getSpeed())
end)

test('direction is queryable and settable', function()
	local timeline = Timeline{duration = 1.0}
	assertEqual('forward', timeline:getDirection())

	timeline:setDirection('reverse')
	assertEqual('reverse', timeline:getDirection())

	timeline:setDirection('forward')
	assertEqual('forward', timeline:getDirection())
end)
