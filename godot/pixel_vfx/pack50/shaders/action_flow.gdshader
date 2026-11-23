shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
uniform float phase=0.0;
uniform float shell=0.0;
uniform float seed=0.0;
uniform float material_kind=0.0;
uniform float cooling=0.0;
uniform float supplied=1.0;
uniform float is_barrier=0.0;
void fragment(){
 vec2 cell=floor(UV*vec2(40.0,34.0));
 vec2 p=(cell+.5)/vec2(40.0,34.0);
 float t=floor(phase*12.0)/12.0;
 // Sparse, advected channels; mask never increases with effect lifetime.
 float lane=sin(p.x*25.1327+p.y*8.0-t*(2.0+seed*.13)+seed*3.1);
 float grain=px_noise(vec2(cell.x*.32+seed,cell.y*.18-t*1.9));
 float density=shell<.5?.48:(shell<1.5?.32:.06);
 if(material_kind>.5 && material_kind<1.5){
  lane=sin(p.x*31.4+p.y*14.0-t*7.0+seed);
  density=shell<.5?.60:(shell<1.5?.44:.12);
 }
 if(material_kind>1.5) density=shell<.5?.56:(shell<1.5?.39:.10);
 if(lane*.45+grain*.6<density || p.y>.992)discard;
 if(is_barrier>.5 && p.y<1.0-supplied)discard;
 if(is_barrier>.5 && shell>1.5 && sin(p.x*35.0+p.y*18.0-t*4.0)<.82)discard;
 // The short white core belongs to the advancing shoulder, not the entire tube.
 if(shell>1.5 && p.y<.63 && is_barrier<.5)discard;
 float h=shell<.5?(.03+grain*.31):shell<1.5?(.29+grain*.42):(.76+grain*.24);
 if(is_barrier>.5)h=min(h,shell<.5?.18:(shell<1.5?.56:.78));
 h=clamp(h-cooling*(shell<1.5?.2:.38),0.0,1.0);
 vec3 col=px_ramp(h,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
 ALBEDO=col;
}
