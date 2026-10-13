shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
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
uniform float style=0.0;
void fragment(){
 vec2 cell=floor(UV*vec2(16.0,20.0));
 vec2 p=(cell+.5)/vec2(16.0,20.0);
 // A continuous liquid skin; the glint slides on the surface, never holes it.
 float light=.5+.5*dot(normalize(NORMAL),normalize(vec3(-.4,.8,.5)));
 float glint=pow(max(0.0,sin(p.x*6.283+p.y*3.0-phase*1.4)),8.0);
 float value=.18+.32*light+.22*glint-.08*cooling;
 ALBEDO=px_ramp(value,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
