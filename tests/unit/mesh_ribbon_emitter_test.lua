-- Unit tests for src/emitters/mesh_ribbon_emitter.lua
local LoveMock = require('tests.support.love_mock')
love = LoveMock.new()

local MeshRibbonEmitter = require('src.emitters.mesh_ribbon_emitter')

test('emitter starts with no segments and no mesh', function()
    local e = MeshRibbonEmitter.new({maxSegments = 10, width = 16, lifetime = 0.5})
    assertEqual(0, #e._segments, 'no segments initially')
    assertEqual(nil, e._mesh, 'no mesh initially')
    assertTrue(e._meshDirty, 'mesh dirty initially')
end)

test('update adds segments when moving above minSpeed', function()
    local e = MeshRibbonEmitter.new({maxSegments = 10, width = 16, lifetime = 0.5, minSpeed = 50})
    e:update(0.016, {x = 0, y = 0}, {x = 100, y = 0})
    assertEqual(1, #e._segments, 'one segment added')
    assertTrue(e._segments[1].age >= 0, 'new segment has age >= 0')
end)

test('update does not add segments below minSpeed', function()
    local e = MeshRibbonEmitter.new({maxSegments = 10, width = 16, lifetime = 0.5, minSpeed = 50})
    e:update(0.016, {x = 0, y = 0}, {x = 10, y = 0})
    assertEqual(0, #e._segments, 'no segments added below minSpeed')
end)

test('segments age and expire after lifetime', function()
    local e = MeshRibbonEmitter.new({maxSegments = 10, width = 16, lifetime = 0.1, minSpeed = 0})
    e:update(0.05, {x = 0, y = 0}, {x = 100, y = 0})
    e:update(0.05, {x = 10, y = 0}, {x = 100, y = 0})
    e:update(0.05, {x = 20, y = 0}, {x = 100, y = 0})
    -- After 3 updates of 0.05: first segment age=0.15 (expired), second=0.10 (expired), third=0.05 (alive)
    assertEqual(1, #e._segments, 'one segment still alive after lifetime')
    
    e:update(0.1, {x = 30, y = 0}, {x = 100, y = 0})
    assertEqual(0, #e._segments, 'all segments expired after lifetime')
end)

test('reset clears segments and mesh', function()
    local e = MeshRibbonEmitter.new({maxSegments = 10, width = 16, lifetime = 0.5, minSpeed = 0})
    e:update(0.016, {x = 0, y = 0}, {x = 100, y = 0})
    e:reset()
    assertEqual(0, #e._segments, 'segments cleared')
    assertEqual(nil, e._mesh, 'mesh cleared')
    assertTrue(e._meshDirty, 'mesh dirty after reset')
end)

test('done returns true when no segments', function()
    local e = MeshRibbonEmitter.new({maxSegments = 10, width = 16, lifetime = 0.5, minSpeed = 0})
    assertTrue(e:done(), 'done when empty')
    e:update(0.016, {x = 0, y = 0}, {x = 100, y = 0})
    assertFalse(e:done(), 'not done with segments')
end)

test('fadeInTime and fadeOutTime options are stored', function()
    local e = MeshRibbonEmitter.new({
        maxSegments = 10,
        width = 16,
        lifetime = 1.0,
        minSpeed = 0,
        fadeInTime = 0.2,
        fadeOutTime = 0.3,
    })
    assertEqual(0.2, e.fadeInTime, 'fadeInTime stored')
    assertEqual(0.3, e.fadeOutTime, 'fadeOutTime stored')
end)

test('debugAlphaColor option is stored', function()
    local e = MeshRibbonEmitter.new({
        maxSegments = 10,
        width = 16,
        lifetime = 1.0,
        minSpeed = 0,
        debugAlphaColor = true,
    })
    assertTrue(e.debugAlphaColor, 'debugAlphaColor stored as true')

    local e2 = MeshRibbonEmitter.new({maxSegments = 10, width = 16, lifetime = 1.0, minSpeed = 0})
    assertFalse(e2.debugAlphaColor, 'debugAlphaColor defaults to false')
end)

test('maxSegments caps the segment count', function()
    local e = MeshRibbonEmitter.new({maxSegments = 3, width = 16, lifetime = 10, minSpeed = 0})
    for i = 1, 5 do
        e:update(0.016, {x = i * 10, y = 0}, {x = 100, y = 0})
    end
    assertEqual(3, #e._segments, 'segments capped at maxSegments')
end)

test('texture scroll offset updates', function()
    local e = MeshRibbonEmitter.new({maxSegments = 10, width = 16, lifetime = 1.0, minSpeed = 0, textureScroll = 1.0})
    e:update(1.0, {x = 0, y = 0}, {x = 100, y = 0})
    assertEqual(1.0 % 1.0, e._scrollOffset, 'scroll offset wraps at 1.0')
end)

print('All mesh_ribbon_emitter tests passed!')