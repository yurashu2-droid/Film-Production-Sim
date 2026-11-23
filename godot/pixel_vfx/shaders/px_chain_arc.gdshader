shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0=vec3(.012,.025,.11);
uniform vec3 pal_1=vec3(.045,.12,.43);
uniform vec3 pal_2=vec3(.16,.52,1.55);
uniform vec3 pal_3=vec3(.8,1.65,2.5);
uniform vec3 pal_4=vec3(4.8,5.2,4.3);
uniform float phase=0.0;
uniform float pulse=0.0;
uniform float layer=0.0;
uniform float variant=0.0;
uniform float res=64.0;
float center(float y){
 float segment=floor(y*8.0);
 float local=fract(y*8.0);
 float a=sin(segment*2.14+variant*1.81)*.23;
 float b=sin((segment+1.0)*2.14+variant*1.81)*.23;
 return mix(a,b,local)+.04*sin(y*18.0+floor(phase*12.0)*.3);
}
void fragment(){
 vec2 cell=floor(UV*vec2(res,res*1.2));
 vec2 p=(cell+.5)/vec2(res,res*1.2);
 float y=p.y;
 float x=(p.x-.5)*2.0;
 float front=clamp(pulse/.28,0.0,1.0);
 float stopped=clamp((pulse-(.30-layer*.025))/.38,0.0,1.08);
 float main_distance=abs(x-center(y));
 float branch_distance=2.0;
 // Each discharge has a different branching history, not a mirror or copied line.
 for(int j=0;j<3;j++){
  float at=.24+float(j)*.23;
  float run=(y-at)/(.28-float(j)*.035);
  float sign_dir=mod(float(j)+variant,2.0)<1.0? -1.0:1.0;
  float branch=center(at)+sign_dir*run*(.4+.08*variant)+sin(run*7.0+float(j))*.04;
  if(run>0.0 && run<1.0 && y<front-.07*float(j))branch_distance=min(branch_distance,abs(x-branch));
 }
 float width=layer<.5 ?.112:(layer<1.5 ?.064:.021);
 float d=min(main_distance,branch_distance*.95);
 if(d>width || y>front || y<stopped)discard;
 float h=layer<.5 ?.22:(layer<1.5 ?.57:.93);
 if(branch_distance<main_distance)h-=.12;
 ALBEDO=px_ramp(h,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
