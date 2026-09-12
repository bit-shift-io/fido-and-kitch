// Voronoi dynamic split-screen compositing shader.
//
// Uniforms:
//   CanvasA, CanvasB   – the two per-player render targets (tex2d)
//   line_point         – a point on the dividing line, in screen pixels
//   line_normal        – unit normal to the dividing line, in screen pixels
//   split_factor       – 0 = fully merged (just CanvasA), 1 = fully split
//   line_thickness     – width of the dividing line in screen pixels
//   line_color         – RGB colour of the dividing line (0..1 each)
//
// The dividing line is given directly as a point + unit normal (computed once
// by CameraManager) rather than derived here from the two players' screen
// positions. Sides are assigned by the signed distance from screenCoord to
// the line, so its width is constant no matter how far apart or how
// diagonally the players sit -- no thickening/blurring near the screen edges
// or at close range.

#ifdef GL_ES
precision mediump float;
#endif

extern sampler2D CanvasA;
extern sampler2D CanvasB;
extern vec2 line_point;
extern vec2 line_normal;
extern float split_factor;
extern float line_thickness;
extern vec3 line_color;

vec4 effect(vec4 color, sampler2D tex, vec2 texCoord, vec2 screenCoord) {
    vec4 colA = texture2D(CanvasA, texCoord);
    if (split_factor <= 0.0) {
        return colA;
    }

    vec4 colB = texture2D(CanvasB, texCoord);

    // Signed distance (pixels) to the line: 0 on the line, <0 on P1's side,
    // >0 on P2's side.
    float sd = dot(screenCoord - line_point, line_normal);

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
