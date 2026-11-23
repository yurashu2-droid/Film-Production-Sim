shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
uniform float phase=0.0;
uniform float seed=0.0;
uniform float front=0.0;
uniform float drain=0.0;
uniform float mode=0.0;
void fragment(){
 vec2 cell=floor(UV*64.0);
 vec2 p=(cell+.5)/64.0-.5;
 float r=length(p)*2.0;
 float a=atan(p.y,p.x);
 float w=.055+.018*sin(a*5.0+seed);
 float crest=front+.042*sin(a*5.0+phase*1.5+seed);
 float band=abs(r-crest);
 if(mode>.5 && mode<1.5){
   // Ground pressure follows bent fractures, rather than a generic circle.
   band=abs(sin(a*3.0+r*7.0+seed))*.2;
   if(r>front || r<.1)discard;
 }else if(mode>2.5){
   // Local impact scorch / alternating contact. Outward cracks sweep clear.
   band=abs(p.y-sin(p.x*13.0+seed)*.095);
   if(abs(p.x)>.34 || r>front*.8 || p.x<drain*.75-.4)discard;
 }else if(mode>1.5){
   band=abs(p.y-sin(p.x*9.0+seed)*.042);
   if(p.x>front-.5 || p.x<drain-.5 || abs(p.x)>.46)discard;
 }
 if(band>w || r>1.0)discard;
 if(sin(a*5.0+seed*2.0)>.55)discard;
 float sector=fract((a+3.14159)/6.28318+seed*.13);
 if(sector<drain)discard;
 float grain=px_noise(cell*.17+seed);
 if(grain<.37)discard;
 float h=clamp(.22+grain*.5-drain*.25,0.0,1.0);
 ALBEDO=px_ramp(h,cell,pal_0,pal_1,pal_2,pal_3,pal_4)*.30;
}
