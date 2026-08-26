-- Simple vertex color test for LÖVE 12
-- Run with: love . e2e=tests/e2e/vertex_color_test.lua

function love.load()
    love.window.setMode(800, 600)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    
    -- Simplest possible mesh
    testMesh = love.graphics.newMesh({
        {100, 300},
        {200, 300},
        {150, 200},
    }, "triangles")
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(testMesh)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Should see: Red-Green-Blue triangle", 10, 10)
    love.graphics.print("If all white: vertex colors not working", 10, 30)
    love.graphics.print("Press ESC to exit", 10, 50)
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end
end