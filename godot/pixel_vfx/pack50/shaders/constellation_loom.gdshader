shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform float phase=0.0;
uniform float open=0.0;
uniform float close=0.0;
uniform float layer=0.0;
uniform float res=44.0;
uniform float seed=0.0;
uniform float curve=.18;
uniform float packet=0.0;
uniform int mode=0;
uniform int sector=0;
uniform vec3 pal_0=vec3(.03,.01,.16);
uniform vec3 pal_1=vec3(.12,.03,.6);
uniform vec3 pal_2=vec3(.65,.18,1.9);
uniform vec3 pal_3=vec3(1.2,2.6,4.0);
uniform vec3 pal_4=vec3(3.4,5.0,5.0);
void vertex(){
 vec2 p=UV*2.0-1.0;
 if(mode==0) VERTEX.z+=curve*(p.x*p.x*.6+p.y*p.y*.4)+curve*.14*sin(p.y*6.0-floor(phase*12.0)/12.0*2.0+layer);
}
float segment(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0));}
void fragment(){
 vec2 cell=floor(UV*res);
 vec2 p=(cell+.5)/res*2.0-1.0;
 float t=floor(phase*12.0)/12.0;
 float a=atan(p.y,p.x),turn=fract(a/6.283185+1.0),r=length(p);
 float light=0.0;
 if(mode<=1){
  float order=fract(turn*4.0+mod(layer,2.0)*.5+float(sector)*.25);
  float opening_order=mode==1?(p.x+1.0)*.5:order;
  float closing_order=mode==1?(1.0-p.x)*.5:order;
  if(opening_order>open || closing_order<close || close>=.999)discard;
  float lobe=.025*sin(a*8.0+layer*.45-t*.9);
  if(mode==1){
   if(r>.58)discard;
   float star=step(.995,px_hash(cell+seed));
   light=star;
  }else{
  float outer=.98-layer*.075+lobe,inner=outer-.16;
  if(r>outer || r<inner)discard;
  float weave=sin(turn*50.26548+r*33.0-t*(mod(layer,2.0)<.5?2.0:-2.0));
  float alternating=step(.5,fract(turn*8.0+floor(t*1.6)*.5));
  light=.14+.22*alternating+.30*pow(max(weave,0.0),2.0)+.20*(1.0-(r-inner)/.16);
  }
 }else if(mode==2){
  float tail=packet-UV.x;
  if(tail<0.0 || tail>.32 || UV.x<close || UV.x>open)discard;
  float width=.22+.60*sin(clamp(tail/.32,0.0,1.0)*3.14159);
  if(abs(p.y)>width)discard;
  light=(1.0-tail/.32)*(.45+.4*step(.58,fract(UV.x*20.0-t*2.0+UV.y*3.0)));
 }else{
  if((p.x+1.0)*.5>open || (1.0-p.x)*.5<close || close>=.999)discard;
  vec2 v0=vec2(-.7,-.4),v1=vec2(.0,.65),v2=vec2(.72,-.28),v3=vec2(.1,-.64);
  if(mode==4){v0=vec2(-.82,-.32);v1=vec2(-.36,.60);v2=vec2(.34,.28);v3=vec2(.82,-.45);}
  float line=min(min(segment(p,v0,v1),segment(p,v1,v2)),min(segment(p,v2,v3),segment(p,v3,v0)));
  if(mode==4)line=min(min(segment(p,v0,v1),segment(p,v1,v2)),segment(p,v2,v3));
  float crosses=0.0;
  vec2 q=p-v0;crosses=max(crosses,step(max(min(abs(q.x),abs(q.y))*3.0,max(abs(q.x),abs(q.y))),.12));
  q=p-v1;crosses=max(crosses,step(max(min(abs(q.x),abs(q.y))*3.0,max(abs(q.x),abs(q.y))),.12));
  q=p-v2;crosses=max(crosses,step(max(min(abs(q.x),abs(q.y))*3.0,max(abs(q.x),abs(q.y))),.12));
  q=p-v3;crosses=max(crosses,step(max(min(abs(q.x),abs(q.y))*3.0,max(abs(q.x),abs(q.y))),.12));
  if(line>.04 && crosses<.5)discard;
  light=.20+.36*crosses+.15*step(.55,fract((p.x+p.y)*8.0-t*.6));
 }
 ALBEDO=mode==1?mix(pal_0*.1,pal_2*.6,light):px_ramp(light,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
