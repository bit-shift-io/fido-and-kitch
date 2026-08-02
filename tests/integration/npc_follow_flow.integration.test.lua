-- Integration test for full NPC follow flow: cage unlock -> NPC spawns -> follows player -> exit door opens

local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = 'tests/fixtures/npc_follow_test.lua'

test('cage unlock spawns NPC and enables exit door when all cages unlocked', function()
    local game = GameHarness.startGame(MAP)
    local controller = FakeInput.new()
    
    -- Wait for game to initialize and players to settle
    FrameStepper.step(game, 60)
    
    -- Get the InGameState to access players
    local inGameState = game.fsm.states.InGameState
    
    -- Give player the keys needed for cages
    local player1 = inGameState.players[1]
    player1.inventory:addItems('key_red', 1)
    player1.inventory:addItems('key_blue', 1)
    print("Player 1 inventory after adding keys: key_red=" .. (player1.inventory.items['key_red'] or 0) .. ", key_blue=" .. (player1.inventory.items['key_blue'] or 0))
    
    -- Verify initial state: 2 cages, exit door not usable
    local cages = Queries.findEntitiesByType(map, 'cage')
    assertTrue(#cages >= 2, 'Should have 2 cages')
    
    local exitDoor = Queries.findEntityByType(map, 'exit_door')
    assertTrue(exitDoor ~= nil, 'Should have exit door')
    assertFalse(exitDoor.usable.enabled, 'Exit door should not be usable initially')
    
    -- Debug: check world colliders
    print("World colliders count: " .. tostring(#world.colliders))
    for collider, _ in pairs(world.colliders) do
        print("  Collider: x=" .. tostring(collider.x) .. ", y=" .. tostring(collider.y) .. ", w=" .. tostring(collider.width) .. ", h=" .. tostring(collider.height) .. ", entity=" .. tostring(collider.entity and collider.entity.name) .. ", type=" .. tostring(collider.entity and collider.entity.type))
    end
    
    -- Player 1 moves right to first cage (bird cage center at x=176)
    -- Player starts at x=80 (center), cage at x=176 = 96 pixels away
    -- Falls for ~0.35s (21 frames), then moves on ground
    -- Reaches cage at ~0.96s (58 frames) after spawn
    -- Initial 60 frames + 58 frames = 118 frames total
    print("Player 1 starting position: x=" .. tostring(inGameState.players[1].x) .. ", y=" .. tostring(inGameState.players[1].y))
    controller:press('right')
    FrameStepper.step(game, 45) -- Move to cage position (after initial 60)
    print("Player 1 position after moving: x=" .. tostring(inGameState.players[1].x) .. ", y=" .. tostring(inGameState.players[1].y))
    controller:press('rshift') -- Press use when at cage
    FrameStepper.step(game, 20)
    controller:release('rshift')
    FrameStepper.step(game, 10)
    controller:release('right')
    FrameStepper.step(game, 30)
    
    print("Player 1 inventory after first cage attempt: key_red=" .. (player1.inventory.items['key_red'] or 0) .. ", key_blue=" .. (player1.inventory.items['key_blue'] or 0))
    
    -- Bird NPC should have spawned (from first cage)
    local birdNPCs = Queries.findEntitiesByType(map, 'bird_npc')
    print("Bird NPCs found: " .. #birdNPCs)
    assertTrue(#birdNPCs >= 1, 'Bird NPC should spawn from first cage')
    
    -- Player 1 moves to second cage (rabbit cage center at x=276)
    -- Distance from first cage (176) to second cage (276) = 100 pixels = 1 second = 60 frames
    controller:press('right')
    FrameStepper.step(game, 40) -- Move to second cage position
    print("Player 1 position before second cage: x=" .. tostring(inGameState.players[1].x) .. ", y=" .. tostring(inGameState.players[1].y))
    controller:press('rshift')
    FrameStepper.step(game, 20)
    controller:release('rshift')
    FrameStepper.step(game, 10)
    controller:release('right')
    FrameStepper.step(game, 90) -- Wait for door animation to complete (1 second = 60 frames)
    
    print("Player 1 inventory after second cage attempt: key_red=" .. (player1.inventory.items['key_red'] or 0) .. ", key_blue=" .. (player1.inventory.items['key_blue'] or 0))
    
    -- Rabbit NPC should have spawned
    local rabbitNPCs = Queries.findEntitiesByType(map, 'rabbit_npc')
    print("Rabbit NPCs found: " .. #rabbitNPCs)
    assertTrue(#rabbitNPCs >= 1, 'Rabbit NPC should spawn from second cage')
    
    -- All cages unlocked -> exit door should be usable
    assertTrue(exitDoor.usable.enabled, 'Exit door should be usable after all cages unlocked')
end)

test('NPCs follow player after spawning', function()
    local game = GameHarness.startGame(MAP)
    local controller = FakeInput.new()
    
    -- Get the InGameState to access players
    local inGameState = game.fsm.states.InGameState
    
    -- Give player the key
    local player1 = inGameState.players[1]
    player1.inventory:addItems('key_red', 1)
    
    FrameStepper.step(game, 60)
    
    -- Unlock first cage (same timing as first test)
    controller:press('right')
    FrameStepper.step(game, 45)
    controller:press('rshift')
    FrameStepper.step(game, 20)
    controller:release('rshift')
    FrameStepper.step(game, 10)
    controller:release('right')
    FrameStepper.step(game, 30)
    
    -- Get bird NPC position
    local birdNPCs = Queries.findEntitiesByType(map, 'bird_npc')
    assertTrue(#birdNPCs > 0, 'Bird NPC should spawn')
    
    local birdX = birdNPCs[1].x
    local birdY = birdNPCs[1].y
    print("Bird NPC initial position: x=" .. tostring(birdX) .. ", y=" .. tostring(birdY))
    
    -- Move player away
    controller:press('right')
    FrameStepper.step(game, 180)
    controller:release('right')
    
    -- Bird should have followed (moved closer to player)
    local newBirdX = birdNPCs[1].x
    print("Bird NPC final position: x=" .. tostring(newBirdX) .. ", y=" .. tostring(birdNPCs[1].y))
    assertTrue(newBirdX > birdX, 'Bird NPC should follow player horizontally')
end)

return true