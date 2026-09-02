-- Visual test for mesh ribbon vertex colors/alpha
-- Run with: love . e2e=tests/unit/mesh_ribbon_render_test.lua

local MeshRibbonEmitter = require("src.emitters.mesh_ribbon_emitter")

local emitter = MeshRibbonEmitter.new({
	maxSegments = 20,
	width = 32,
	lifetime = 1.0,
	minSpeed = 0,
	colorStart = { 1, 1, 1, 1 },
	colorEnd = { 1, 1, 1, 0 },
	fadeInTime = 0.1,
	fadeOutTime = 0.5,
	debugAlphaColor = true,
})

local timer = 0
local segments = 0

function love.load()
	love.window.setMode(800, 600)
	love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
end

function love.update(dt)
	timer = timer + dt

	-- Add new segments continuously
	local pos = { x = 100 + timer * 50, y = 300 + math.sin(timer * 2) * 50 }
	local vel = { x = 100, y = math.cos(timer * 2) * 50 }
	emitter:update(dt, pos, vel)
	segments = #emitter._segments
end

function love.draw()
	emitter:draw()

	-- Debug info
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print("Mesh Ribbon Vertex Color Test", 10, 10)
	love.graphics.print(string.format("Segments: %d", segments), 10, 30)
	love.graphics.print(string.format("Timer: %.1f", timer), 10, 50)
	love.graphics.print("Should see: Yellow (head) -> Blue (tail) gradient", 10, 70)
	love.graphics.print("If all white: vertex colors not working", 10, 90)
	love.graphics.print("Press ESC to exit", 10, 110)
end

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	end
end
