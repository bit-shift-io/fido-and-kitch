package.path = package.path .. ';assets/?.lua'

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

local function prequire(m) 
    local ok, err = pcall(require, m) 
    if not ok then return nil, err end
    return err
end

function Map:createEntitiesFromObjectGroupLayers()
    for _, layer in ipairs(self.map.layers) do
		if layer.type == "objectgroup" then
			layer.visible = false
            for _, object in ipairs(layer.objects) do
                -- move to a util function with option to supress error
                local ok, err = pcall(require, object.type) 
                if not ok then
                    print(err)
                else
                    local entity = err(object)
                    entity.new("qwe") -- testing inheritance... why is the arg not being passed?
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