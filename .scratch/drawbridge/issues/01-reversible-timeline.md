Status: done

# Reversible Timeline/Sprite playback API

## What to build

A caller can drive a `Sprite`'s animation in both directions from a single asset: play it forward from the start, play it in reverse from the end, and reverse direction from the current frame mid-playback. A finish signal fires both when a forward play reaches the end and when a reverse play reaches the start, so an owning entity can react to "open finished" and "close finished" from one animation. Direction and speed are queryable and settable. Existing forward-only consumers (ladder, switch, exit door, etc.) keep behaving exactly as before.

This is the animation foundation the drawbridge's open (forward) / close (reverse) transitions build on. It's verifiable on its own through unit tests, with no drawbridge yet.

## Files to create/modify

- src/components/timeline.lua — harden/expose the reverse primitives (`isReverse`, `reverse()`, `resetReverse()`, `speed`, dual-end finish in `fireEvents`) into a deliberate public API; ensure `playing` stops cleanly at both ends
- src/components/sprite.lua — surface forward/reverse/reverse-mid-playback controls that map onto the Timeline API; confirm `getFrameIndex` is correct at both ends
- tests/timeline_reverse_test.lua — new
- tests/run.lua — register the new test

## Test approach

Headless `tests/*_test.lua` in the project's fast-regression style (no LÖVE launch):
- Forward play to the end fires the finish signal exactly once and lands on the last frame; `playing` becomes false (non-looping).
- Reverse play from the end reaches the start, fires finish exactly once, lands on the first frame.
- Reversing mid-playback flips direction and, after stepping, lands on the expected frame moving the other way.
- Frame index is in-bounds and correct at both extremes across a range of frame counts.
- A forward-only play (no reverse calls) behaves identically to today — guard against regressing existing consumers.

## Acceptance criteria

- [x] Public API: play forward, play reverse, reverse mid-playback, set/get direction, set/get speed.
- [x] Finish signal fires at the forward end and at the reverse end.
- [x] Frame index correct and in-bounds at both ends.
- [x] Existing forward-only animations are unaffected.
- [x] New tests registered in `tests/run.lua` and passing via `./test.sh`.

## Blocked by

None — can start immediately.

## Implementation notes

Delivered as `Timeline:playForward()` / `:playReverse()` / `:reverseFromCurrent()` / `:getDirection()` / `:setDirection()` / `:getSpeed()` / `:setSpeed()` / `:isPlaying()`, mirrored on `Sprite` (which also syncs `frameNum` immediately so a draw right after triggering shows the correct frame without waiting a tick). `tests/timeline_reverse_test.lua`, 7 tests, all green; full suite green aside from a pre-existing unrelated flaky camera test (confirmed flaky on `main` before this feature too).
