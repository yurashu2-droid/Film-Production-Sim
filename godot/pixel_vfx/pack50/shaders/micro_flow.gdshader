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
 vec2 res=vec2(18.0,22.0);
 vec2 cell=floor(UV*res);
 vec2 p=(cell+.5)/res;
 float wave=sin(p.x*18.85+p.y*(style<.5?8.0:13.0)-phase*5.0+seed);
 float patch=px_noise(vec2(cell.x*.39+seed,cell.y*.24-phase*2.2));
 float density=wave*.32+patch*.6;
 if(density<(layer<.5?.40:(layer<1.5?.28:.17)))discard;
 if(layer>1.5 && (abs(p.y-.35)>.15 || COLOR.r>.64))discard;
 float v=clamp(.30+patch*.43+p.y*.23-cooling*.5,0.0,1.0);
 if(style>1.5)v=clamp(.30+patch*.32+wave*.1-cooling*.12,.08,.65);
 if(layer<.5)v=min(v,.37);
 if(layer>1.5 && style<1.5)v=max(v,.72-cooling*.35);
 ALBEDO=px_ramp(v,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
