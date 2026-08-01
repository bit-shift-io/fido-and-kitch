-- Shared death/spawn flash-and-fade sequence, extracted from what used to
-- be inlined across Player:die, player_states.DeadState, and
-- Player:startSpawnFlash. Both Player and NPC call this instead of each
-- owning their own copy of the alpha tween + Flash wiring.
local Flash = require('src.components.flash')

local DeathFlash = {}

DeathFlash.FLASH_INTERVAL = 0.15
DeathFlash.FLASH_BLINKS = 8
DeathFlash.FADE_DURATION = DeathFlash.FLASH_INTERVAL * DeathFlash.FLASH_BLINKS

-- Death sequence: alpha fades 1->0 over FADE_DURATION while a blocking Flash
-- toggles `visible`; onComplete fires once the flash finishes blinking (the
-- entity should already be locked/non-solid by the time this is called).
function DeathFlash.startDeath(entity, onComplete)
	entity.alpha = 1
	entity.fadeTween = Tween.new(DeathFlash.FADE_DURATION, entity, {alpha = 0})

	entity.flash = entity:addComponent(Flash{
		target = entity,
		property = 'visible',
		interval = DeathFlash.FLASH_INTERVAL,
		blinks = DeathFlash.FLASH_BLINKS,
		onComplete = onComplete,
	})
end

-- Spawn/respawn sequence: alpha fades 0->1 over FADE_DURATION while a
-- non-blocking Flash toggles `visible` -- the entity is active immediately,
-- there is no completion gate.
function DeathFlash.startSpawn(entity)
	entity.alpha = 0
	entity.fadeTween = Tween.new(DeathFlash.FADE_DURATION, entity, {alpha = 1})

	entity.flash = entity:addComponent(Flash{
		target = entity,
		property = 'visible',
		interval = DeathFlash.FLASH_INTERVAL,
		blinks = DeathFlash.FLASH_BLINKS,
	})
end

return DeathFlash
