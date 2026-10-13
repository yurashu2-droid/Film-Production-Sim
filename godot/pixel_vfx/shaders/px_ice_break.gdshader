shader_type spatial;
render_mode cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0; uniform vec3 pal_1; uniform vec3 pal_2; uniform vec3 pal_3; uniform vec3 pal_4;
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform float layer = 0.0;
uniform float crack = 0.0;
uniform float melt = 0.0;
uniform float water = 0.0;
void fragment() {
    vec2 cell = floor(UV * vec2(14.0, 18.0));
    vec2 p = (cell + 0.5) / vec2(14.0, 18.0);
    if (p.y < melt) { discard; } // Hot edge melts in one direction; no lifetime holes.
    float edge = min(min(p.x, 1.0-p.x), min(p.y, 1.0-p.y));
    float fissure = abs(p.x - (0.33 + 0.15*sin(p.y*9.0 + seed)));
    bool broken = fissure < 0.065 && p.y < crack;
    if (layer < 0.5 && edge > 0.19 && !broken) { discard; }
    if (layer > 0.5 && layer < 1.5 && mod(cell.x + cell.y*2.0 + seed, 11.0) < 1.0) { discard; }
    if (layer > 1.5 && (!broken || water > 0.5)) { discard; }
    float value = layer < 0.5 ? 0.16 : (layer < 1.5 ? 0.45 + 0.18*p.y : 0.93);
    if (broken && layer < 1.5) { value = 0.12; }
    if (water > 0.5) { value = layer < 0.5 ? 0.13 : 0.36; }
    vec3 col = px_ramp(value, cell, pal_0, pal_1, pal_2, pal_3, pal_4);
    ALBEDO = col;
    EMISSION = col * (layer > 1.5 ? 0.6 : 0.025);
    ROUGHNESS = 0.7;
}
