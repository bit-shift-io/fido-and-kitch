// Voronoi dynamic split-screen compositing shader.
//
// Uniforms:
//   CanvasA, CanvasB   – the two per-player render targets (tex2d)
//   p1_screen          – screen-space UV of player 1's focal point [0..1]
//   p2_screen          – screen-space UV of player 2's focal point [0..1]
//   split_factor       – 0 = fully merged (just CanvasA), 1 = fully split
//   line_thickness     – width of the dividing line in screen pixels
//   line_color         – RGB colour of the dividing line (0..1 each)
//
// The dividing line is the perpendicular bisector of the two focal points.
// Sides are assigned the same way as comparing Euclidean distances, but the
// line is drawn from the true signed distance to the bisector (in pixels), so
// its width is constant no matter how far apart or how diagonally the players
// sit -- no thickening/blurring near the screen edges or at close range.

#ifdef GL_ES
precision mediump float;
#endif

extern sampler2D CanvasA;
extern sampler2D CanvasB;
extern vec2 p1_screen;
extern vec2 p2_screen;
extern float split_factor;
extern float line_thickness;
extern vec3 line_color;

vec4 effect(vec4 color, sampler2D tex, vec2 texCoord, vec2 screenCoord) {
    vec4 colA = texture2D(CanvasA, texCoord);
    if (split_factor <= 0.0) {
        return colA;
    }

    vec4 colB = texture2D(CanvasB, texCoord);

    // Work in screen pixels so the line width is a true pixel measure.
    vec2 px = screenCoord;
    vec2 p1px = p1_screen * love_ScreenSize.xy;
    vec2 p2px = p2_screen * love_ScreenSize.xy;

    vec2 sep = p2px - p1px;
    float sepLen = length(sep);
    if (sepLen < 0.0001) {
        // Focal points coincide: no meaningful divider, just show P1's canvas.
        return colA;
    }
    vec2 n = sep / sepLen;                    // unit normal to the bisector
    vec2 c = (p1px + p2px) * 0.5;             // midpoint of the two players

    // Signed distance (pixels) to the bisector: 0 on the line, <0 on P1's
    // side, >0 on P2's side.
    float sd = dot(px - c, n);

    // Voronoi side via the bisector -- equivalent to comparing |px-p1|
    // against |px-p2|.
    vec4 voronoiResult = (sd <= 0.0) ? colA : colB;

    // Consistent pixel-width line, anti-aliased over a 1px edge.
    float halfw = line_thickness * 0.5;
    float line = 1.0 - smoothstep(halfw - 1.0, halfw + 1.0, abs(sd));

    // Composite: Voronoi canvases blend in with split_factor (smooth camera
    // ease), but the dividing line is full opacity the moment this pass is
    // active -- no fade/emergence, and a stable width throughout.
    vec4 result = mix(colA, voronoiResult, split_factor);
    result.rgb = mix(result.rgb, line_color, line);

    return result;
}
