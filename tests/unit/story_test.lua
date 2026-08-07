-- Two tiers of coverage for src/entities/story.lua, both headless:
--
-- 1. Pure decision-helper tests against Story._internal -- fast,
--    construction-free, one assertion per branch: the per-line NES typewriter
--    ramp (letters -> words -> slab), line/cooldown math, overlap detection,
--    and bubble geometry.
--
-- 2. Entity-level tests that construct a real Story -- real Collider, real
--    Usable/Sound, a real bump World -- via tests/support/headless_bootstrap,
--    and drive it through Story:use(user) / Story:update(dt) the way the game
--    does. These cover the per-player bubble state: show/skip/dismiss,
--    cooldown gating, auto-dismiss on overlap end, and the blip sound.
--
-- See tests/unit/drawbridge_test.lua for the same two-tier split.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local SoundSpy = require('tests.support.sound_spy')

local Story = require('src.entities.story')
local T = Story._internal.typewriter
local C = Story._internal.cooldown
local B = Story._internal.bubble
local W = Story._internal.wrap
local PO = Story._internal.playerOverlaps

--
-- Part 1: pure decision helpers
--

test('splitLines turns the text property into lines on \\n', function()
	local lines = T.splitLines('Line one\nLine two')
	assertEqual(2, #lines)
	assertEqual('Line one', lines[1])
	assertEqual('Line two', lines[2])
end)

test('splitLines handles a single line and empty text', function()
	local single = T.splitLines('Hello!')
	assertEqual(1, #single)
	assertEqual('Hello!', single[1])
	assertEqual(0, #T.splitLines(''))
	assertEqual(0, #T.splitLines(nil))
end)

test('a short line reveals entirely by letter-rate (no word phase)', function()
	local C = Story._internal.CONST
	-- 'hi' is 2 chars; the whole line fits inside the letter phase
	assertNear(2 / C.LETTER_RATE, T.lineDuration('hi'), 1e-6)
	assertEqual(1, T.revealedCount('hi', 0))
	assertEqual(2, T.revealedCount('hi', 1 / C.LETTER_RATE))
	assertEqual(2, T.revealedCount('hi', 0.05))
	assertEqual(2, T.revealedCount('hi', 999))
end)

test('a line longer than the letter phase adds a word phase', function()
	local C = Story._internal.CONST
	local letterPhase = C.LETTER_COUNT / C.LETTER_RATE
	assertNear(letterPhase + C.WORD_PHASE, T.lineDuration('hello world'), 1e-6)
end)

test('revealedCount starts at one character at t=0', function()
	assertEqual(1, T.revealedCount('hello world', 0))
end)

test('revealedCount reveals one character at a time during the letter phase', function()
	local C = Story._internal.CONST
	assertEqual(2, T.revealedCount('hello world', 1 / C.LETTER_RATE))
	assertEqual(3, T.revealedCount('hello world', 2 / C.LETTER_RATE))
end)

test('revealedCount caps at the letter count during the letter phase', function()
	local C = Story._internal.CONST
	-- inside the letter phase (3.5 chars in), clamped to LETTER_COUNT
	assertEqual(C.LETTER_COUNT, T.revealedCount('hello world', 3.5 / C.LETTER_RATE))
	assertEqual(C.LETTER_COUNT, T.revealedCount('hello world', (C.LETTER_COUNT - 0.1) / C.LETTER_RATE))
end)

test('revealedCount is monotonic non-decreasing over the whole ramp', function()
	local last = 0
	for t = 0, 0.3, 0.005 do
		local count = T.revealedCount('hello world', t)
		assertTrue(count >= last, 'revealedCount regressed at t=' .. tostring(t))
		last = count
	end
end)

test('revealedCount reaches the full line length once the word phase completes', function()
	local line = 'hello world'
	assertEqual(#line, T.revealedCount(line, T.lineDuration(line)))
	assertEqual(#line, T.revealedCount(line, 999))
end)

test('a single-word line reveals the whole word after the letter phase', function()
	assertEqual(5, T.revealedCount('hello', Story._internal.CONST.LETTER_COUNT / Story._internal.CONST.LETTER_RATE))
end)

test('visibleText reveals line by line, then the full slab', function()
	local R = Story._internal.CONST.LETTER_RATE
	local lines = { 'Hi', 'there', 'friend' }
	-- still inside line 1's letter phase (0.5 chars in): line 1 partial ('H'),
	-- later lines empty
	local early = T.visibleText(lines, 0.5 / R)
	assertEqual('H', early[1])
	assertEqual('', early[2])
	assertEqual('', early[3])

	-- line 1 done, line 2 partial ('t')
	local mid = T.visibleText(lines, 2.5 / R)
	assertEqual('Hi', mid[1])
	assertEqual('t', mid[2])
	assertEqual('', mid[3])

	-- past the total duration: everything revealed
	local late = T.visibleText(lines, T.totalDuration(lines) + 0.1)
	assertEqual('Hi', late[1])
	assertEqual('there', late[2])
	assertEqual('friend', late[3])
end)

test('isFullyRevealed is true only once the reveal elapsed passes the total duration', function()
	local lines = T.splitLines('Hello there\nfriend')
	assertFalse(T.isFullyRevealed(0, lines))
	assertTrue(T.isFullyRevealed(T.totalDuration(lines), lines))
	assertTrue(T.isFullyRevealed(T.totalDuration(lines) + 1, lines))
end)

test('cooldown canShow treats nil and zero as ready and positive time as locked', function()
	assertTrue(C.canShow(nil))
	assertTrue(C.canShow(0))
	assertFalse(C.canShow(0.3))
	assertTrue(C.canShow(-0.001))
end)

test('playerOverlaps reflects collider overlap in the world', function()
	HeadlessBootstrap.resetWorld()
	local story = Story({
		x = 128, y = 96, width = 32, height = 32,
		properties = { text = 'Hello!' },
	})
	local inside = Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, 24, 48},
		body_type = 'static',
		position = {x = 144, y = 96},
	}
	local outside = Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, 24, 48},
		body_type = 'static',
		position = {x = 300, y = 300},
	}

	assertTrue(PO(world, story.collider, inside))
	assertFalse(PO(world, story.collider, outside))
	assertFalse(PO(world, nil, inside))
	assertFalse(PO(world, story.collider, nil))
end)

test('bubble screenPoint projects a world point through the camera transform', function()
	local x, y = B.screenPoint(100, 50, 10, 20, 2, 3)
	assertNear(220, x, 1e-6)
	assertNear(210, y, 1e-6)
end)

test('bubble box width sizes to the widest line plus padding', function()
	local measure = function(line) return #line * 10 end
	assertEqual(30 + 2 * Story._internal.CONST.PADDING, B.boxWidth({'ab', 'abc'}, measure))
	assertEqual(40 + 2 * Story._internal.CONST.PADDING, B.boxWidth({'ab', 'abcd'}, measure))
end)

test('bubble box height is lines times line height plus padding', function()
	assertEqual(3 * 16 + 2 * Story._internal.CONST.PADDING, B.boxHeight(3, 16))
end)

test('wrapLine leaves a fitting line alone', function()
	local measure = function(line) return #line * 10 end
	local out = W.wrapLine('abc', measure, 40)
	assertEqual(1, #out)
	assertEqual('abc', out[1])
end)

test('wrapLine greedily wraps a long line at word boundaries', function()
	local measure = function(line) return #line * 10 end
	-- each wrapped line may hold up to 4 chars (40 / 10)
	local out = W.wrapLine('one two three four', measure, 40)
	assertEqual('one|two|three|four', table.concat(out, '|'))
end)

test('wrapLine keeps a single oversized word on its own line', function()
	local measure = function(line) return #line * 10 end
	local out = W.wrapLine('longword here', measure, 40)
	assertEqual('longword|here', table.concat(out, '|'))
end)

test('wrapLines flattens wrapped sub-lines across lines', function()
	local measure = function(line) return #line * 10 end
	local out = W.wrapLines({'one two', 'three four'}, measure, 40)
	assertEqual('one|two|three|four', table.concat(out, '|'))
end)

test('wrapLines keeps already-fitting multi-lines intact', function()
	local measure = function(line) return #line * 10 end
	local out = W.wrapLines({'ab', 'cd'}, measure, 40)
	assertEqual('ab|cd', table.concat(out, '|'))
end)

--
-- Part 2: entity-level, against a real constructed Story
--

local function makeStory(text)
	HeadlessBootstrap.resetWorld()
	return Story({
		x = 128, y = 96, width = 32, height = 32,
		properties = { text = text or 'Hello!' },
	})
end

-- a bare static collider standing in for a player, positioned so the test
-- controls overlap; mirrors the fake-collider convention in drawbridge_test
local function makePlayer(x, y)
	local collider = Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, 24, 48},
		body_type = 'static',
		position = {x = x, y = y},
	}
	local player = { collider = collider }
	collider.entity = player
	return player
end

test('constructs headless with a sensor collider, usable, sound, and text', function()
	local story = makeStory('Hello!\nWorld')

	assertEqual('story', story.type)
	assertEqual('Hello!\nWorld', story.text)
	assertTrue(story.collider:isSensor(), 'story trigger should be a sensor')
	assertTrue(story:getComponent(Usable) ~= nil)
	assertTrue(story:getComponent(Sound) ~= nil)
end)

test('use shows a bubble for that player only', function()
	local story = makeStory()
	local p1 = makePlayer(144, 96)
	local p2 = makePlayer(300, 300)

	story:use(p1)

	assertTrue(story.bubbles[p1].visible)
	assertTrue(story.bubbles[p2] == nil)
end)

test('both players can show bubbles on the same entity independently', function()
	local story = makeStory()
	local p1 = makePlayer(144, 96)
	local p2 = makePlayer(300, 300)
	p2.collider:setPosition(144, 96)

	story:use(p1)
	story:use(p2)

	assertTrue(story.bubbles[p1].visible)
	assertTrue(story.bubbles[p2].visible)
end)

test('use mid-reveal skips the typewriter to fully revealed', function()
	local story = makeStory('A fairly long line here')
	local p1 = makePlayer(144, 96)

	story:use(p1)
	assertFalse(T.isFullyRevealed(story.bubbles[p1].revealElapsed, story.lines))

	story:use(p1) -- mid-reveal

	assertTrue(T.isFullyRevealed(story.bubbles[p1].revealElapsed, story.lines))
	assertTrue(story.bubbles[p1].visible, 'skip must not dismiss')
end)

test('next use after fully revealed dismisses and starts the cooldown', function()
	local story = makeStory()
	local p1 = makePlayer(144, 96)

	story:use(p1) -- show
	story:use(p1) -- skip to full
	story:use(p1) -- dismiss

	assertFalse(story.bubbles[p1].visible)
	assertTrue(story.bubbles[p1].cooldownTimer > 0)
end)

test('immediate re-use within the cooldown is blocked', function()
	local story = makeStory()
	local p1 = makePlayer(144, 96)

	story:use(p1)
	story:use(p1)
	story:use(p1) -- dismiss; cooldown now running

	story:use(p1) -- within cooldown

	assertFalse(story.bubbles[p1].visible)
end)

test('stepping past the cooldown allows re-show', function()
	local story = makeStory()
	local p1 = makePlayer(144, 96)

	story:use(p1)
	story:use(p1)
	story:use(p1) -- dismissed, cooldown = COOLDOWN

	story:update(Story._internal.CONST.COOLDOWN) -- drain the cooldown
	story:use(p1)

	assertTrue(story.bubbles[p1].visible)
end)

test('a blip sound plays when the bubble appears', function()
	local story = makeStory()
	local p1 = makePlayer(144, 96)
	local spy = SoundSpy.install()

	story:use(p1)

	assertEqual('blip', spy.played[1])
	spy.uninstall()
end)

test('update advances the reveal while the player still overlaps', function()
	local story = makeStory()
	local p1 = makePlayer(144, 96)

	story:use(p1)
	local before = story.bubbles[p1].revealElapsed
	story:update(1/60)

	assertTrue(story.bubbles[p1].revealElapsed > before)
	assertTrue(story.bubbles[p1].visible, 'bubble stays visible while overlapping')
end)

test('update auto-dismisses when the triggering player no longer overlaps', function()
	local story = makeStory()
	local p1 = makePlayer(144, 96)

	story:use(p1)
	assertTrue(story.bubbles[p1].visible)

	p1.collider:setPosition(300, 300)
	story:update(1/60)

	assertFalse(story.bubbles[p1].visible)
	assertTrue(story.bubbles[p1].cooldownTimer > 0, 'overlap-end dismiss also starts the cooldown')
end)
