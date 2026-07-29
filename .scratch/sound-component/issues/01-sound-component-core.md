Status: done

# 01: Sound Component Core

## What to build
Create the `Sound` component at `src/components/sound.lua` that loads WAV files and plays them by name with random pitch variation. Register it globally in `src/main.lua`.

## Files to create/modify
- src/components/sound.lua (new)
- src/main.lua (add Sound global require)

## Test approach
Unit test: mock `love.audio.newSource`, verify source created with correct path, `setPitch` called with value in [0.9, 1.1], `play()` called. Test unknown sound logs warning.

## Acceptance criteria
- [ ] Sound component loads sounds table on init
- [ ] play(name) creates Source, sets pitch ±10%, plays
- [ ] Unknown name logs warning, no error
- [ ] destroy() stops all owned sources
- [ ] Sound global available in all files
- [ ] Unit tests pass

## Blocked by
None — can start immediately