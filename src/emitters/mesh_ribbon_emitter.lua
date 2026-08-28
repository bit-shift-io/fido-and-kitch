-- src/emitters/mesh_ribbon_emitter.lua — true extruding mesh ribbon trail
--
-- Maintains a continuous triangulated mesh ribbon. Vertices are added at the head
-- each frame based on movement direction, and expired vertices are trimmed from the tail.
-- Single draw call via love.graphics.draw(mesh).
--
--   local MeshRibbonEmitter = require('src.emitters.mesh_ribbon_emitter')
--   local emitter = MeshRibbonEmitter.new({
--       maxSegments = 60,        -- max ribbon length in segments
--       width = 24,              -- ribbon width (world units)
--       lifetime = 0.6,          -- seconds before tail fades
--       colorStart = {1,0.9,0.5,1},
--       colorEnd = {1,0.3,0.1,0},
--       texture = 'res/img/fx/fx_blob_glow.png',
--       textureScaleV = 1.0,     -- V texture coordinate scale
--       textureScroll = 2.0,     -- UV scroll speed (per second)
--   })
--   emitter:update(dt, position, velocity)
--   emitter:draw()
--
-- Call update each frame with current position and velocity. The emitter
-- automatically extrudes the ribbon along the velocity vector.
local MeshRibbonEmitter = {}

local AssetManager = require('src.utils.asset_manager')
local Log = require('src.utils.log')

local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local Emitter = {}
Emitter.__index = Emitter

function Emitter:init(opts)
    opts = opts or {}
    self.maxSegments = opts.maxSegments or 60
    self.width = opts.width or 24
    self.lifetime = opts.lifetime or 0.6
    self.colorStart = opts.colorStart or {1, 0.9, 0.5, 1}
    self.colorEnd = opts.colorEnd or {1, 0.3, 0.1, 0}
    self.texture = opts.texture
    self.textureScaleV = opts.textureScaleV or 1.0
    self.textureScroll = opts.textureScroll or 0
    self.minSpeed = opts.minSpeed or 50
    self.fadeInTime = opts.fadeInTime or 0.1
    self.fadeOutTime = opts.fadeOutTime or 0.5
    self.debugAlphaColor = opts.debugAlphaColor or false
    
    self._segments = {}  -- {pos, age, velocity}
    self._mesh = nil
    self._meshDirty = true
    self._texture = nil
    self._scrollOffset = 0
    self._lastPos = nil
    
    if self.texture then
        self:_loadTexture()
    end
end

function Emitter:_loadTexture()
    if type(self.texture) == 'string' then
        if love.filesystem and love.filesystem.getInfo and not love.filesystem.getInfo(self.texture) then
            Log.warn('MeshRibbon texture not found: ' .. tostring(self.texture))
            return
        end
        self._texture = AssetManager.getImage(self.texture)
    elseif self.texture and self.texture.getWidth then
        self._texture = self.texture
    end
end

-- Update ribbon: add new segment at current position with velocity, age existing, trim tail
function Emitter:update(dt, pos, vel)
    local speed = vel and math.sqrt(vel.x * vel.x + vel.y * vel.y) or 0
    
    -- Only add segment if moving (speed > 0) and above minSpeed
    if speed > 0 and speed >= self.minSpeed then
        local dirX, dirY = 0, -1
        if speed > 0.001 then
            dirX, dirY = vel.x / speed, vel.y / speed
        end
        
        -- Direction is stored per segment; perpendicular computed dynamically in _rebuildMesh
        local segment = {
            x = pos.x,
            y = pos.y,
            age = 0,
            dirX = dirX,
            dirY = dirY,
            halfWidth = self.width * 0.5,
            speed = speed,
        }
        
        table.insert(self._segments, 1, segment)
        self._meshDirty = true
    end
    
    -- Age all segments
    local alive = 0
    for i = 1, #self._segments do
        local s = self._segments[i]
        s.age = s.age + dt
        if s.age < self.lifetime then
            alive = alive + 1
            self._segments[alive] = s
        end
    end
    -- Trim dead segments
    local trimmed = false
    for i = alive + 1, #self._segments do
        self._segments[i] = nil
        trimmed = true
    end
    if trimmed then
        self._meshDirty = true
    end
    
    -- Cap at maxSegments
    while #self._segments > self.maxSegments do
        table.remove(self._segments)
    end
    
    -- Update texture scroll
    self._scrollOffset = (self._scrollOffset + self.textureScroll * dt) % 1.0
end

function Emitter:_rebuildMesh()
    if #self._segments < 2 then
        self._mesh = nil
        return
    end
    
    local verts = {}
    local segCount = #self._segments
    
    local fadeInTime = self.fadeInTime or 0.1
    local fadeOutTime = self.fadeOutTime or 0.5
    
    for i = 1, segCount do
        local s = self._segments[i]
        local t = clamp(s.age / self.lifetime, 0, 1)
        
        -- Alpha with fade-in/fade-out
        local baseAlpha = lerp(self.colorStart[4], self.colorEnd[4], t)
        local alpha = baseAlpha
        
        -- Fade in at start (ease-in)
        if t < fadeInTime then
            local ft = t / fadeInTime
            alpha = alpha * (ft * ft * (3 - 2 * ft))
        end
        
        -- Fade out at end (ease-out)
        if t > 1 - fadeOutTime then
            local ft = (t - (1 - fadeOutTime)) / fadeOutTime
            alpha = alpha * (1 - ft * ft * (3 - 2 * ft))
        end
        
        local a = math.floor(alpha * 255)
        
        -- Color: either from colorStart/colorEnd, or debug alpha visualization
        local r, g, b
        if self.debugAlphaColor then
            -- Debug: visualize ACTUAL alpha (with fadeIn/fadeOut easing) as color
            -- white=opaque, blue=transparent
            local alphaNorm = alpha  -- already computed with fadeIn/fadeOut
            r = math.floor(alphaNorm * 255)
            g = math.floor(alphaNorm * 255)
            b = math.floor((1 - alphaNorm) * 255)
        else
            r = math.floor(lerp(self.colorStart[1], self.colorEnd[1], t) * 255)
            g = math.floor(lerp(self.colorStart[2], self.colorEnd[2], t) * 255)
            b = math.floor(lerp(self.colorStart[3], self.colorEnd[3], t) * 255)
        end
        
        -- UV coordinates
        local u = 0
        local u2 = 1
        local v = (i - 1) / math.max(1, segCount - 1) * self.textureScaleV + self._scrollOffset
        
        -- Compute perpendicular from stored direction
        local perpX, perpY = -s.dirY, s.dirX
        
        -- Left vertex
        table.insert(verts, s.x - perpX * s.halfWidth)
        table.insert(verts, s.y - perpY * s.halfWidth)
        table.insert(verts, u)
        table.insert(verts, v)
        table.insert(verts, r)
        table.insert(verts, g)
        table.insert(verts, b)
        table.insert(verts, a)
        
        -- Right vertex
        table.insert(verts, s.x + perpX * s.halfWidth)
        table.insert(verts, s.y + perpY * s.halfWidth)
        table.insert(verts, u2)
        table.insert(verts, v)
        table.insert(verts, r)
        table.insert(verts, g)
        table.insert(verts, b)
        table.insert(verts, a)
    end
    
    -- Build table of tables for LÖVE 12 format+location syntax
    -- Each vertex is a table with 8 values: x, y, u, v, r, g, b, a
    -- Normalize color to 0-1 range for floatvec4 format
    local meshVerts = {}
    for i = 1, #verts, 8 do
        table.insert(meshVerts, {
            verts[i], verts[i+1],                              -- VertexPosition (x, y)
            verts[i+2], verts[i+3],                            -- VertexTexCoord (u, v)
            verts[i+4]/255, verts[i+5]/255, verts[i+6]/255, verts[i+7]/255  -- VertexColor (r, g, b, a) 0-1
        })
    end
    
    self._mesh = love.graphics.newMesh({
        {name = "VertexPosition", format = "floatvec2", location = 0},
        {name = "VertexTexCoord", format = "floatvec2", location = 1},
        {name = "VertexColor", format = "floatvec4", location = 2},
    }, meshVerts, "strip")
    
    if not self._mesh then
        return
    end
    
    if self._texture then
        self._mesh:setTexture(self._texture)
    end
    
    self._meshDirty = false
end

function Emitter:draw()
    if #self._segments < 2 then return end
    
    if self._meshDirty or not self._mesh then
        self:_rebuildMesh()
    end
    
    if self._mesh then
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Use provided texture, or 1x1 white fallback (needed for vertex colors to render)
        local tex = self._texture
        if not tex then
            if not self._whiteTexture then
                local imgData = love.image.newImageData(1, 1)
                imgData:setPixel(0, 0, 1, 1, 1, 1)
                self._whiteTexture = love.graphics.newImage(imgData)
            end
            tex = self._whiteTexture
        end
        self._mesh:setTexture(tex)
        
        love.graphics.draw(self._mesh)
    end
end

function Emitter:done()
    return #self._segments == 0
end

function Emitter:reset()
    self._segments = {}
    self._mesh = nil
    self._meshDirty = true
    self._scrollOffset = 0
    self._lastPos = nil
end

function MeshRibbonEmitter.new(opts)
    local emitter = setmetatable({}, Emitter)
    emitter:init(opts)
    return emitter
end

return MeshRibbonEmitter