# Dynamic Voronoi Split-Screen Camera System for LÖVE (Love2D)

A complete architectural guide and reference implementation for creating a seamless, dynamic 2-player split-screen camera system in LÖVE (Love2D). This system transitions continuously from a unified, dynamically zoomed camera to a dynamic Voronoi directional split screen.

---

## 1. Architectural Overview

### The 3-State Camera Lifecycle

To prevent abrupt visual pops, the camera system smoothly interpolates across three core operational states based on the world distance $D = \|P_1 - P_2\|$ between Player 1 and Player 2:

```
 Distance (D):   0.0 ------------------> D_merged ------------------> D_split ------------------> ∞
 Camera State:   [  1. MERGED STATE  ]  [  2. TRANSITION STATE  ]  [   3. SPLIT VORONOI STATE   ]
 Visual Mode:    Single Camera View     Dynamic Zoom-Out           Dual Canvases + GLSL Shader
```

1. **Merged State ($D \le D_{	ext{merged}}$):**
   * A single camera centers on the midpoint $M = rac{P_1 + P_2}{2}$.
   * The camera zoom level remains at default scale ($1.0$).
   * World is rendered onto a single canvas.

2. **Transition / Zoom-Out State ($D_{	ext{merged}} < D < D_{	ext{split}}$):**
   * The single camera stays centered at the midpoint $M$.
   * Camera scale dynamically zooms out ($	ext{scale} < 1.0$) to keep both players fully visible within the single viewport.
   * Eliminates abrupt screen splits when players are slightly separated.

3. **Split Voronoi State ($D \ge D_{	ext{split}}$):**
   * The system switches to dual cameras, each locked to its respective player with smooth positional smoothing (lerp).
   * Both views render into off-screen canvases (`CanvasA` and `CanvasB`).
   * A screen-space GLSL fragment shader composites the two canvases using Voronoi tessellation based on player relative vectors, rendering a dynamic, angled dividing line.

---

## 2. Mathematical Foundations

### Dynamic Midpoint & Zoom Factor
When both players share a view, the camera origin $(M_x, M_y)$ and required zoom scale $S$ are computed as:

$$M = rac{P_1 + P_2}{2}$$

$$S = 	ext{clamp}\left( rac{	ext{Viewport Height}}{\|P_1 - P_2\| + 	ext{Padding}}, S_{	ext{min}}, 1.0 ight)$$

### Screen-Space Voronoi Tessellation
In the split state, every pixel/fragment at screen coordinates $F = (u, v) \in [0, 1]^2$ determines which player canvas to sample by comparing Euclidean distances to the projected screen targets $T_1$ and $T_2$:

$$d_1 = \|F - T_1\|, \quad d_2 = \|F - T_2\|$$

$$	ext{Pixel Assignment} = egin{cases} 	ext{Canvas A (Player 1)}, & 	ext{if } d_1 < d_2 - rac{w}{2} \ 	ext{Dividing Line Color}, & 	ext{if } |d_1 - d_2| \le rac{w}{2} \ 	ext{Canvas B (Player 2)}, & 	ext{if } d_2 < d_1 - rac{w}{2} \end{cases}$$

where $w$ represents the normalized thickness of the dividing border line.

---

## 3. Shader Implementation

Save this GLSL shader code as `voronoi_split.glsl` in your LÖVE project directory.

```glsl
// voronoi_split.glsl
extern Image CanvasB;        // Player 2 offscreen render target
extern vec2 p1_screen;       // Normalized screen coordinate of Player 1 [0.0, 1.0]
extern vec2 p2_screen;       // Normalized screen coordinate of Player 2 [0.0, 1.0]
extern float split_factor;   // Smooth transition factor [0.0 = fully merged, 1.0 = fully split]
extern float line_thickness; // Normalized width of the dividing line
extern vec4 line_color;      // RGBA color of the dividing line

vec4 effect(vec4 color, Image CanvasA, vec2 texture_coords, vec2 screen_coords) {
    // Direct pass-through if fully merged
    if (split_factor <= 0.0) {
        return Texel(CanvasA, texture_coords) * color;
    }

    // Measure distance from current fragment to each player's screen anchor point
    float dist1 = distance(texture_coords, p1_screen);
    float dist2 = distance(texture_coords, p2_screen);

    // Sample both canvases
    vec4 colA = Texel(CanvasA, texture_coords);
    vec4 colB = Texel(CanvasB, texture_coords);

    // Calculate Voronoi boundary
    float diff = dist1 - dist2;
    float half_line = line_thickness * 0.5;

    vec4 final_color;

    if (abs(diff) < half_line) {
        // Draw dividing line
        final_color = line_color;
    } else if (dist1 < dist2) {
        // Pixel is closer to Player 1
        final_color = colA;
    } else {
        // Pixel is closer to Player 2
        final_color = colB;
    }

    // Smoothly blend between merged state (colA) and split state during transition phase
    return mix(colA, final_color, split_factor) * color;
}
```

---

## 4. Complete Lua Implementation (`main.lua`)

Below is the complete, runnable LÖVE codebase demonstrating smooth transitions, zoom scaling, hysteresis, and Voronoi split-screen rendering.

```lua
-- main.lua
local canvasA, canvasB
local splitShader

-- World & Player Entities
local player1 = { x = 300, y = 400, color = {0.2, 0.6, 1.0} }
local player2 = { x = 500, y = 400, color = {1.0, 0.3, 0.3} }

-- Camera Configuration Parameters
local CONFIG = {
    d_merged = 350,        -- Distance below which camera remains at 1x zoom
    d_split = 700,         -- Distance at which screen becomes fully split
    min_zoom = 0.55,       -- Maximum zoom-out scale factor
    padding = 150,         -- World unit buffer around players when calculating zoom
    lerp_speed = 6.0,      -- Smoothing rate for camera movement
    line_thickness = 0.006,-- Thickness of division line in screen UV space
    line_color = {0.1, 0.1, 0.1, 1.0}
}

-- Camera Runtime State
local cam = {
    p1 = { x = 300, y = 400 },
    p2 = { x = 500, y = 400 },
    mid = { x = 400, y = 400 },
    zoom = 1.0,
    split_factor = 0.0
}

function love.load()
    local w, h = love.graphics.getDimensions()
    
    -- Instantiate Offscreen Canvases
    canvasA = love.graphics.newCanvas(w, h)
    canvasB = love.graphics.newCanvas(w, h)
    
    -- Load Shader
    splitShader = love.graphics.newShader("voronoi_split.glsl")
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function clamp(val, min_val, max_val)
    return math.max(min_val, math.min(max_val, val))
end

function love.update(dt)
    -- Movement Controls
    local speed = 350
    if love.keyboard.isDown("a") then player1.x = player1.x - speed * dt end
    if love.keyboard.isDown("d") then player1.x = player1.x + speed * dt end
    if love.keyboard.isDown("w") then player1.y = player1.y - speed * dt end
    if love.keyboard.isDown("s") then player1.y = player1.y + speed * dt end

    if love.keyboard.isDown("left")  then player2.x = player2.x - speed * dt end
    if love.keyboard.isDown("right") then player2.x = player2.x + speed * dt end
    if love.keyboard.isDown("up")    then player2.y = player2.y - speed * dt end
    if love.keyboard.isDown("down")  then player2.y = player2.y + speed * dt end

    -- 1. Calculate Target Positions & Distance
    local dx = player2.x - player1.x
    local dy = player2.y - player1.y
    local dist = math.sqrt(dx * dx + dy * dy)

    local target_mid_x = (player1.x + player2.x) / 2
    local target_mid_y = (player1.y + player2.y) / 2

    -- 2. Calculate Smooth Transitions (Zoom & Split Factor)
    local screen_w, screen_h = love.graphics.getDimensions()
    
    -- Calculate target zoom scale based on distance
    local target_zoom = screen_h / (dist + CONFIG.padding)
    target_zoom = clamp(target_zoom, CONFIG.min_zoom, 1.0)

    -- Calculate normalized split factor [0.0 = Merged, 1.0 = Split]
    local target_split = (dist - CONFIG.d_merged) / (CONFIG.d_split - CONFIG.d_merged)
    target_split = clamp(target_split, 0.0, 1.0)

    -- 3. Interpolate Camera State
    local t = math.min(1.0, dt * CONFIG.lerp_speed)
    cam.p1.x = lerp(cam.p1.x, player1.x, t)
    cam.p1.y = lerp(cam.p1.y, player1.y, t)
    cam.p2.x = lerp(cam.p2.x, player2.x, t)
    cam.p2.y = lerp(cam.p2.y, player2.y, t)
    cam.mid.x = lerp(cam.mid.x, target_mid_x, t)
    cam.mid.y = lerp(cam.mid.y, target_mid_y, t)
    cam.zoom = lerp(cam.zoom, target_zoom, t)
    cam.split_factor = lerp(cam.split_factor, target_split, t)
end

function love.draw()
    local w, h = love.graphics.getDimensions()

    -- -------------------------------------------------------------------------
    -- RENDER PASS 1: Render Player 1 View (or Merged View) -> Canvas A
    -- -------------------------------------------------------------------------
    love.graphics.setCanvas(canvasA)
    love.graphics.clear(0.15, 0.15, 0.18, 1.0)
    love.graphics.push()
        love.graphics.translate(w / 2, h / 2)
        if cam.split_factor < 1.0 then
            -- Blend between Midpoint and P1 camera center
            local cx = lerp(cam.mid.x, cam.p1.x, cam.split_factor)
            local cy = lerp(cam.mid.y, cam.p1.y, cam.split_factor)
            local cz = lerp(cam.zoom, 1.0, cam.split_factor)
            love.graphics.scale(cz, cz)
            love.graphics.translate(-cx, -cy)
        else
            love.graphics.scale(1.0, 1.0)
            love.graphics.translate(-cam.p1.x, -cam.p1.y)
        end
        drawWorld()
    love.graphics.pop()

    -- -------------------------------------------------------------------------
    -- RENDER PASS 2: Render Player 2 View -> Canvas B (Only if splitting)
    -- -------------------------------------------------------------------------
    if cam.split_factor > 0.0 then
        love.graphics.setCanvas(canvasB)
        love.graphics.clear(0.15, 0.15, 0.18, 1.0)
        love.graphics.push()
            love.graphics.translate(w / 2, h / 2)
            love.graphics.scale(1.0, 1.0)
            love.graphics.translate(-cam.p2.x, -cam.p2.y)
            drawWorld()
        love.graphics.pop()
    end

    love.graphics.setCanvas() -- Reset to primary frame buffer

    -- -------------------------------------------------------------------------
    -- RENDER PASS 3: Composite Pass via Voronoi Shader
    -- -------------------------------------------------------------------------
    -- Calculate normalized screen coordinates for Voronoi targets
    local p1_uv = {
        lerp(0.5, 0.5 + (cam.p1.x - cam.mid.x) * cam.zoom / w, 1.0 - cam.split_factor),
        lerp(0.5, 0.5 + (cam.p1.y - cam.mid.y) * cam.zoom / h, 1.0 - cam.split_factor)
    }
    local p2_uv = {
        lerp(0.5, 0.5 + (cam.p2.x - cam.mid.x) * cam.zoom / w, 1.0 - cam.split_factor),
        lerp(0.5, 0.5 + (cam.p2.y - cam.mid.y) * cam.zoom / h, 1.0 - cam.split_factor)
    }

    -- If fully split, direction vector derives from actual player world relative offset
    if cam.split_factor >= 0.99 then
        local angle = math.atan2(player2.y - player1.y, player2.x - player1.x)
        p1_uv = { 0.5 - math.cos(angle) * 0.25, 0.5 - math.sin(angle) * 0.25 }
        p2_uv = { 0.5 + math.cos(angle) * 0.25, 0.5 + math.sin(angle) * 0.25 }
    end

    splitShader:send("CanvasB", canvasB)
    splitShader:send("p1_screen", p1_uv)
    splitShader:send("p2_screen", p2_uv)
    splitShader:send("split_factor", cam.split_factor)
    splitShader:send("line_thickness", CONFIG.line_thickness)
    splitShader:send("line_color", CONFIG.line_color)

    love.graphics.setShader(splitShader)
    love.graphics.draw(canvasA, 0, 0)
    love.graphics.setShader()

    -- Render UI elements over final composite
    drawUI()
end

function drawWorld()
    -- Render a background grid for visual movement tracking
    love.graphics.setColor(0.25, 0.28, 0.32)
    local grid_size = 100
    for x = -2000, 2000, grid_size do
        love.graphics.line(x, -2000, x, 2000)
    end
    for y = -2000, 2000, grid_size do
        love.graphics.line(-2000, y, 2000, y)
    end

    -- Render Player 1
    love.graphics.setColor(player1.color)
    love.graphics.circle("fill", player1.x, player1.y, 24)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("P1", player1.x - 8, player1.y - 8)

    -- Render Player 2
    love.graphics.setColor(player2.color)
    love.graphics.circle("fill", player2.x, player2.y, 24)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("P2", player2.x - 8, player2.y - 8)
end

function drawUI()
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("P1: WASD | P2: Arrow Keys", 10, 10)
    love.graphics.print(string.format("Split Factor: %.2f", cam.split_factor), 10, 28)
    love.graphics.print(string.format("Zoom Level:   %.2f", cam.zoom), 10, 46)
end

function love.resize(w, h)
    -- Re-allocate canvases upon window resize
    canvasA = love.graphics.newCanvas(w, h)
    canvasB = love.graphics.newCanvas(w, h)
end
```

---

## 5. Key UX Refinements & Edge Cases

### A. Angular Hysteresis & Snapping
When players rapidly circle around each other near the split threshold, the screen division angle can rotate violently, causing motion sickness.
* **Solution:** Apply angular smoothing or clamp the division vector angle to discrete steps (e.g., snapping to 15° increments or restricting line rotation speed via `math.atan2` interpolation).

### B. Aspect Ratio Adjustments
When the screen splits vertically versus horizontally:
* Vertical splits reduce horizontal FOV.
* Horizontal splits reduce vertical FOV.
* **Solution:** Adjust the individual camera scale slightly based on the line angle $	heta = rctan2(\Delta y, \Delta x)$. When $	heta pprox 0^\circ$ (side-by-side), slightly decrease vertical FOV to compensate.

### C. HUD & UI Alignment
* **Never render player-specific UI into `canvasA` or `canvasB` before the shader composite pass.**
* Always draw heads-up displays, crosshairs, health bars, and inventory menus in `drawUI()` **after** unbinding the Voronoi shader (`love.graphics.setShader()`) to ensure UI components remain fixed in screen space.

### D. Handle Window Resizing
Ensure you hook into LÖVE's `love.resize(w, h)` callback to re-instantiate both offscreen render targets. Rendering to mismatched canvas dimensions will cause distorted UV mappings and scaling artifacts.
