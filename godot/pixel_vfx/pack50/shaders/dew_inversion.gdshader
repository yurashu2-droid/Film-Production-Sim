shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
uniform float phase=0.0;
uniform float layer=0.0;
uniform int mode=0;
void fragment(){
 vec2 cell=floor(UV*vec2(40.0,56.0));
 vec2 p=(cell+.5)/vec2(40.0,56.0);
 float t=floor(phase*12.0)/12.0;
 float grain=px_fbm(vec2(p.x*8.0+p.y*2.0,p.y*7.0-t*.8));
 float rim=min(p.y,1.0-p.y)*7.0;
 float density=grain+sin(p.x*18.0+p.y*7.0-t*3.0)*.12;
 if(density < (mode==1 ? .35 : .58-layer*.045))discard;
 if(rim<px_bayer(cell)*.65)discard;
 if(mode==1 && abs(p.x-.5)>.46-.06*sin(p.y*9.0+t))discard;
 float lit=clamp(.12+(density-.25)*.65+layer*.13+smoothstep(.72,.94,p.y)*.24,0.0,.92);
 ALBEDO=px_ramp(lit,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
