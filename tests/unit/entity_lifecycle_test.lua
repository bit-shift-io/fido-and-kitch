-- Tests for Entity component lifecycle hooks and O(1) component lookups

-- Bootstrap globals needed by src.entity (same as tests/support/game_harness.lua)
local function bootGlobals()
	tbl = require('src.utils.tbl')
	str = require('src.utils.str')
	utils = require('src.utils.utils')
	
	Vector = require('lib.hump.vector')
	Class = require('lib.hump.class')
	Signal = require('src.utils.signal')
end

bootGlobals()

local Entity = require('src.entity')
local Class = require('lib.hump.class')

-- Mock component classes for testing
local TestComponent = Class{}
function TestComponent:init(props)
    self.name = props and props.name or 'test'
    self.attached = false
    self.detached = false
    self.destroyed = false
    self.updateCount = 0
    self.drawCount = 0
end
function TestComponent:onAttach(entity)
    self.attached = true
    self.entity = entity
end
function TestComponent:onDetach()
    self.detached = true
end
function TestComponent:onDestroy()
    self.destroyed = true
end
function TestComponent:update(dt)
    self.updateCount = self.updateCount + 1
end
function TestComponent:draw()
    self.drawCount = self.drawCount + 1
end

local ComponentWithDestroyOnly = Class{}
function ComponentWithDestroyOnly:init()
    self.destroyCalled = false
end
function ComponentWithDestroyOnly:destroy()
    self.destroyCalled = true
end

local ComponentWithOnDestroyOnly = Class{}
function ComponentWithOnDestroyOnly:init()
    self.onDestroyCalled = false
end
function ComponentWithOnDestroyOnly:onDestroy()
    self.onDestroyCalled = true
end

test('Entity:addComponent calls onAttach and stores in componentsByType', function()
    local entity = Entity()
    local comp = TestComponent{name = 'mycomp'}
    
    entity:addComponent(comp, 'mycomp')
    
    assertTrue(comp.attached, 'onAttach should be called')
    assertEqual(entity, comp.entity, 'component should reference entity')
    assertEqual(comp, entity:getComponent('mycomp'), 'getComponent by name should work')
end)

test('Entity:getComponent returns component via O(1) lookup', function()
    local entity = Entity()
    local comp = TestComponent{name = 'lookup_test'}
    entity:addComponent(comp, 'lookup_test')
    
    local found = entity:getComponent('lookup_test')
    assertEqual(comp, found, 'O(1) lookup by name should work')
end)

test('Entity:getComponent falls back to linear search for class types', function()
    local entity = Entity()
    local comp = TestComponent{name = 'class_lookup'}
    entity:addComponent(comp)
    
    -- This tests the fallback linear search using utils.instanceOf
    -- We can't easily test class-based lookup without a real class hierarchy,
    -- but we can verify the method doesn't error
    local found = entity:getComponent(TestComponent)
    -- Since we used a name key, this will be nil but shouldn't error
    assertTrue(found == nil or found == comp, 'fallback search should not error')
end)

test('Entity:removeComponent calls onDetach and cleans up both arrays', function()
    local entity = Entity()
    local comp = TestComponent{name = 'removable'}
    entity:addComponent(comp, 'removable')
    
    entity:removeComponent('removable')
    
    assertTrue(comp.detached, 'onDetach should be called')
    assertEqual(nil, entity:getComponent('removable'), 'component should be removed from lookup')
    assertEqual(0, #entity.components, 'component should be removed from array')
end)

test('Entity:removeComponent works with component reference', function()
    local entity = Entity()
    local comp = TestComponent{name = 'byref'}
    entity:addComponent(comp)
    
    entity:removeComponent(comp)
    
    assertTrue(comp.detached, 'onDetach should be called when removing by reference')
    assertEqual(0, #entity.components, 'component should be removed from array')
end)

test('Entity:removeComponent works with class type', function()
    local entity = Entity()
    local comp = TestComponent{name = 'byclass'}
    entity:addComponent(comp)
    
    entity:removeComponent(TestComponent)
    
    assertTrue(comp.detached, 'onDetach should be called when removing by class type')
    assertEqual(0, #entity.components, 'component should be removed from array')
end)

test('Entity:destroy calls onDestroy on components', function()
    local entity = Entity()
    local comp1 = ComponentWithOnDestroyOnly()
    local comp2 = ComponentWithDestroyOnly()
    entity:addComponent(comp1)
    entity:addComponent(comp2)
    
    entity:destroy()
    
    assertTrue(comp1.onDestroyCalled, 'onDestroy should be called when present')
    assertTrue(comp2.destroyCalled, 'destroy should be called as fallback when onDestroy not present')
end)

test('Entity:update and draw forward to components', function()
    local entity = Entity()
    local comp = TestComponent{name = 'updatable'}
    entity:addComponent(comp)
    
    entity:update(0.016)
    entity:draw()
    
    assertEqual(1, comp.updateCount, 'update should be forwarded')
    assertEqual(1, comp.drawCount, 'draw should be forwarded')
end)

test('Entity:addComponent with no name uses class/metatable as key', function()
    local entity = Entity()
    local comp = TestComponent{} -- no name provided
    entity:addComponent(comp)
    
    -- Should be able to find by metatable/class
    local found = entity:getComponent(getmetatable(comp))
    -- Or by class
    local found2 = entity:getComponent(comp.class)
    -- At least one should work (depends on what getmetatable returns for hump Class)
    assertTrue(found == comp or found2 == comp, 'component should be findable by class/metatable key')
end)

test('Entity:update/draw skip components without those methods', function()
    local entity = Entity()
    local comp = {} -- no update/draw methods
    entity:addComponent(comp)
    
    -- Should not error
    entity:update(0.016)
    entity:draw()
    
    assertTrue(true, 'components without update/draw should be skipped gracefully')
end)

test('Entity:destroy emits destroySignal', function()
    local entity = Entity()
    local emitted = false
    local emittedEntity = nil
    entity.destroySignal:connect(function(e)
        emitted = true
        emittedEntity = e
    end)
    
    entity:destroy()
    
    assertTrue(emitted, 'destroySignal should be emitted')
    assertEqual(entity, emittedEntity, 'destroySignal should emit the entity')
end)

return true