shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0=vec3(.07,.015,.01);
uniform vec3 pal_1=vec3(.6,.07,.015);
uniform vec3 pal_2=vec3(2.0,.43,.04);
uniform vec3 pal_3=vec3(4.0,1.6,.14);
uniform vec3 pal_4=vec3(6.0,5.3,3.0);
uniform float phase=0.0;
uniform float spread=.0;
uniform float sweep=.0;
uniform float cooled=0.0;
uniform float res=48.0;
uniform float seed=0.0;
uniform int mode=0;
void fragment(){
 vec2 cell=floor(UV*res);
 vec2 p=((cell+.5)/res-.5)*2.0;
 float r=length(p);
 float a=atan(p.y,p.x);
 float angle=fract((a+3.14159)/6.28318+seed);
 bool shape=false;
 if(mode==0)shape=abs(r-spread)<.09+.05*sin(a*5.0+seed) && r<.97;
 else shape=abs(sin(a*5.0+r*9.0))<.24 && r<spread && r>.16;
 if(!shape || angle<sweep)discard;
 float h=clamp(.75-r*.24-cooled*.8,0.0,1.0);
 ALBEDO=px_ramp(h,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
