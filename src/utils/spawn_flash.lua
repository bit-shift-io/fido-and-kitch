-- Shared respawn "spawn flash" timing, used by both players and NPCs on
-- respawn/revive. FADE is the per-blink fade duration in seconds; BLINKS is
-- the number of visibility toggles. Total flash = FADE * BLINKS.
return {
	FADE = 0.15,
	BLINKS = 8,
}
