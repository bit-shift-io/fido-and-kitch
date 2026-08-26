-- src/fx/teleport_burst.lua — bright burst + sparkles for teleporter entry/exit

local Class = require('lib.hump.class')
local FxBase = require('src.fx.base')
local Particles = require('src.emitters.sprite_emitter')

local TeleportBurst = Class{__includes = FxBase}

function TeleportBurst:config()
    return {
        position = {x = 0, y = 0},
        lifetime = {min = 0.3, max = 0.6},
        speed = {min = 50, max = 150},
        direction = {angle = -math.pi / 2, spread = math.pi * 2}, -- omnidirectional
        gravity = {x = 0, y = -50}, -- slight upward float
        size = {start = 12, ["end"] = 2},
        colors = {
            start = {1.0, 0.9, 0.5, 1.0},   -- bright warm white/yellow
            ["end"] = {0.6, 0.3, 1.0, 0.0}  -- magenta fade
        },
        image = 'res/img/fx/fx_blob_glow.png',
        rotation = {angle = 0, spread = math.pi * 2},
        spin = {min = -4, max = 4},
        fadeIn = 0.1,
        area = {w = 16, h = 16},
    }
end

function TeleportBurst:emitCount()
    return 20
end

return TeleportBurst