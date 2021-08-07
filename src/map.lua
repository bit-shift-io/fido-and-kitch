package.path = package.path .. ';assets/?.lua'

local sti = require("sti")

local Map   = {}
Map.__index = Map

function createStaticPhysicsBodies(layer)
    print("createStaticPhysicsBodies TODO")
    --local s = self
end

local function newMap(path, world, debug)
    map = sti(path, { "box2d" })

	-- Prepare collision objects
    if world then
	    map:box2d_init(world)
    end

    for li, layer in ipairs(map.layers) do
        layer.createStaticPhysicsBodies = createStaticPhysicsBodies

    end

    return setmetatable({
        map = map,
        debug = debug or false
      },
      Map
    )
end



local function prequire(m) 
    local ok, err = pcall(require, m) 
    if not ok then return nil, err end
    return err
end

function Map:createStaticPhysicsBodyBoundary()
    local width = self.map.width * self.map.tilewidth
    local height = self.map.height * self.map.tileheight

    local b = Collider{shape_type='Edge', shape_arguments={0, height, width, height}, body_type='static'}
    b:addShape{shape_type='Edge', shape_arguments={0, 0, width, 0}}
    b:addShape{shape_type='Edge', shape_arguments={0, 0, 0, height}}
    b:addShape{shape_type='Edge', shape_arguments={width, 0, width, height}}
    return b
end

function Map:createEntitiesFromObjectGroupLayers()
    -- we basically take each object layer and replace
    -- them with entities
    -- so the layer order is the render order
    for li, layer in ipairs(self.map.layers) do
		if layer.type == "objectgroup" then
            local objects = layer.objects
            layer.entities = {}

            self.map:convertToCustomLayer(li)

	        function layer:update(dt) 
                for _, entity in pairs(self.entities) do
                    entity:update(dt)
                end
            end

            function layer:draw() 
                for _, entity in pairs(self.entities) do
                    entity:draw()
                end
            end

            for _, object in ipairs(objects) do
                -- move to a util function with option to supress error
                local ok, err = pcall(require, object.type) 
                if not ok then
                    print(err)
                else
                    local entity = err(object)
                    table.insert(layer.entities, entity)
                end
            end
		end
	end
end

function Map:update(dt)
    self.map:update(dt)
end

function Map:draw()
    self.map:draw()

	-- Draw Collision Map (useful for debugging)
    if self.debug then
        love.graphics.setColor(1, 0, 0)
        self.map:box2d_draw()
    end
end

return newMap