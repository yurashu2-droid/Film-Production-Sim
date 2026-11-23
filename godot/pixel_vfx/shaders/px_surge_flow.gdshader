shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0=vec3(.07,.015,.01);
uniform vec3 pal_1=vec3(.6,.07,.015);
uniform vec3 pal_2=vec3(2.0,.43,.04);
uniform vec3 pal_3=vec3(4.0,1.6,.14);
uniform vec3 pal_4=vec3(6.0,5.3,3.0);
uniform float phase=0.0;
uniform float layer=0.0;
uniform float seed=0.0;
uniform float eaten=0.0;
uniform float cooled=0.0;
uniform float lane_count=3.0;
uniform vec2 res=vec2(36.0,32.0);
void fragment(){
 vec2 cell=floor(UV*res);
 vec2 p=(cell+.5)/res;
 float t=floor(phase*12.0)/12.0;
 // Flow gaps are permanent advected lanes, never lifetime noise-hole deletion.
 float lane=sin(p.x*6.28318*lane_count + p.y*7.0-t*3.2+seed*4.0);
 float grain=px_noise(vec2(cell.x*.3+seed,cell.y*.17-t*1.7));
 float density=layer<.5 ?.43:(layer<1.5 ?.30:.1);
 if(lane*.5+grain*.6<density || p.y<eaten || p.y>.985)discard;
 if(layer>1.5 && p.y<.78)discard;
 float heat=clamp(.34+.55*grain+.20*p.y-cooled*.65,0.0,1.0);
 if(layer<.5)heat=clamp(.04+grain*.32-cooled*.25,.0,.39);
 else if(layer<1.5)heat=clamp(heat,.30,.78);
 else heat=clamp(heat,.70,1.0);
 ALBEDO=px_ramp(heat,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
