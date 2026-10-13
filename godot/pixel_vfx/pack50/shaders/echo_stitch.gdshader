shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;uniform vec3 pal_1;uniform vec3 pal_2;uniform vec3 pal_3;uniform vec3 pal_4;
uniform float phase=0.0;uniform float shell=0.0;uniform float seed=0.0;uniform float cooling=0.0;
void fragment(){
 vec2 cell=floor(UV*vec2(40.0,36.0));vec2 p=(cell+.5)/vec2(40.0,36.0);
 float t=floor(phase*12.0)/12.0;
 float lane=sin(p.x*25.13+p.y*13.0-t*4.0+seed);
 float grain=px_noise(cell*.21+vec2(seed,-t*1.8));
 float limit=shell<.5?.57:(shell<1.5?.37:.10);
 if(lane*.38+grain*.65<limit)discard;
 if(shell>1.5 && p.y<.73)discard;
 float h=shell<.5?.09+grain*.23:(shell<1.5?.35+grain*.35:.8+grain*.2);
 ALBEDO=px_ramp(clamp(h-cooling*.23,0.0,1.0),cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
