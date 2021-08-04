local sti = require("sti")

local Map   = {}
Map.__index = Map

local function newMap(path, world, debug)
    map = sti(path, { "box2d" })

	-- Prepare collision objects
    if world then
	    map:box2d_init(world)
    end

    return setmetatable({
        map = map,
        debug = debug or false
      },
      Map
    )
end

function Map:createEntitiesFromObjectGroupLayers()
    for _, layer in ipairs(self.map.layers) do
		if layer.type == "objectgroup" then
			layer.visible = false

            for _, object in ipairs(layer.objects) do
                path = 'assets/' .. object.type .. '.lua'
                info = love.filesystem.getInfo(path)
                if info then
                    entity = assert(love.filesystem.load(path))() -- setmetatable(assert(love.filesystem.load(path))(), Map)
                    print('loaded entity')
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