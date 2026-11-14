shader_type spatial;
render_mode cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0; uniform vec3 pal_1; uniform vec3 pal_2; uniform vec3 pal_3; uniform vec3 pal_4;
uniform float phase=0.0; uniform float seed=0.0; uniform float layer=0.0;
void fragment() {
    vec2 cell=floor(UV*vec2(24.0,12.0));
    vec2 p=(cell+.5)/vec2(24.0,12.0);
    float stripe=sin(p.x*18.8496+p.y*5.0-phase*3.0+seed);
    float flow=px_noise(vec2(cell.x*.27+seed,cell.y*.31-phase*.5));
    if (stripe+flow*.6 < (layer<.5?.52:(layer<1.5?.35:-.08))) { discard; }
    float v=layer<.5?.16:(layer<1.5?.44+.20*flow:.86);
    vec3 col=px_ramp(v,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
    ALBEDO=col;
    EMISSION=col*(layer>1.5?.34:.12);
    ROUGHNESS=.95;
}
