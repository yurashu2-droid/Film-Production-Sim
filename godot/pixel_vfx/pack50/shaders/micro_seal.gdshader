shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
uniform float phase=0.0;
uniform float opened=0.0;
uniform float swept=0.0;
uniform float offset=0.0;
uniform float kind=0.0;
uniform float radius=.74;
void fragment(){
 vec2 cell=floor(UV*32.0);
 vec2 p=((cell+.5)/32.0-.5)*2.0;
 float r=length(p);
 float a=fract(atan(p.y,p.x)/6.283185+offset-phase*.13);
 if(a>opened || a<swept)discard;
 float ring=step(abs(r-radius),.08);
 float tick=step(.57,fract(a*(kind<.5?8.0:12.0)))*step(abs(r-.47),.13);
 float segments=step(.1,fract(a*4.0))*step(abs(r-.93),.035);
 if(kind>1.5 && kind<2.5){
  ring=step(abs(r-radius),.045)*(1.0-step(.81,fract(a*3.0)));
  tick=0.0;segments=0.0;
 }
 if(kind>2.5 && kind<3.5){
  float petal=.46+.17*cos(atan(p.y,p.x)*5.0);
  ring=step(abs(r-petal),.055);tick=0.0;segments=0.0;
 }
 if(kind>3.5){
  ring=0.0;
  tick=step(abs(p.x)+abs(p.y),.83)*step(.72,abs(p.x)+abs(p.y));
  segments=0.0;
 }
 if(max(ring,max(tick,segments))<.5)discard;
 ALBEDO=px_ramp(.37+.5*sin(r*8.0-phase*5.0)*sin(r*8.0-phase*5.0),cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
