shader_type spatial;
render_mode cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0; uniform vec3 pal_1; uniform vec3 pal_2; uniform vec3 pal_3; uniform vec3 pal_4;
uniform float phase = 0.0; uniform float seed = 0.0; uniform float layer = 0.0;
void fragment() {
    vec2 cell = floor(UV * vec2(12.0, 22.0));
    vec2 p = (cell + .5) / vec2(12.0,22.0);
    float edge = abs(p.x-.5)*2.0;
    // A permanent porous vein and border; density does not dissolve with age.
    if (layer < .5 && edge < .47 && mod(cell.y+seed,5.0)>1.0) { discard; }
    if (layer > .5 && layer < 1.5 && mod(cell.x+cell.y+seed,9.0)<1.0) { discard; }
    if (layer > 1.5 && (edge>.40 || p.y<.24 || p.y>.77)) { discard; }
    float vein = .5+.5*sin(p.y*8.0-phase*3.0+seed);
    float v = layer < .5 ? .14 : (layer < 1.5 ? .35+.25*vein : .85);
    vec3 col=px_ramp(v,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
    ALBEDO=col;
    EMISSION=col*(layer>1.5?.08:0.0);
    ROUGHNESS=.9;
}
