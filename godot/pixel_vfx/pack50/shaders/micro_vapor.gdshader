shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
uniform float phase=0.0;
uniform float layer=0.0;
uniform float seed=0.0;
uniform float cooling=0.0;
uniform float style=2.0;
void fragment(){
 vec2 cell=floor(UV*vec2(18.0,24.0));
 vec2 p=(cell+.5)/vec2(18.0,24.0);
 float density=px_noise(vec2(p.x*4.0+seed,p.y*5.0-phase*.62));
 float edge=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),.6);
 float diluted=1.0-smoothstep(.43,1.0,COLOR.r);
 ALBEDO=px_ramp(.30+density*.33,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
 ALPHA=(.22+layer*.03)*(.3+density*.7)*edge*diluted;
}
