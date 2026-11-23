shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
uniform float phase = 0.0;
uniform float layer = 0.0;
uniform float seed = 0.0;
uniform float heat = 1.0;
void fragment() {
 vec2 cell=floor(UV*vec2(42.0,36.0));
 vec2 p=(cell+0.5)/vec2(42.0,36.0);
 float t=floor(phase*12.0)/12.0;
 // Broad cloud chambers with permanent open cells; no age-driven hole mask.
 float mist=px_fbm(vec2(p.x*5.0-t*0.25,p.y*4.0-t*0.31+seed));
 float lobe=sin(p.y*13.0+sin(p.x*17.0+seed)*1.4-t*1.7)*0.12;
 float density=mist+lobe;
 if(density < 0.40+layer*0.025) discard;
 float rim=min(p.y,1.0-p.y)*5.0;
 float facing=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),0.65);
 float edge=smoothstep(0.07,0.6,facing);
 if(edge<px_bayer(cell)*0.8) discard;
 if(rim<px_bayer(cell)) discard;
 float v=clamp(0.10+(density-0.3)*0.70+layer*0.04+layer*0.08*smoothstep(0.60,0.90,p.y),0.0,0.82);
 ALBEDO=px_ramp(v,cell,pal_0,pal_1,pal_2,pal_3,pal_4)*heat;
 ALPHA=(0.20+layer*0.13)*edge;
}
