shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
// Floor marks have jobs: star map, eclipse shadow, runoff, fracture anchors,
// hex corners, scanning rails, handoff pads, rune letters. No generic ring.
uniform float phase=0.0;
uniform float res=40.0;
uniform int motif=0;
uniform float open=0.0;
uniform float close=0.0;
uniform float seed=0.0;
uniform vec3 pal_0=vec3(.05,.01,.12);
uniform vec3 pal_1=vec3(.2,.03,.5);
uniform vec3 pal_2=vec3(.5,.3,1.2);
uniform vec3 pal_3=vec3(1.2,1.5,2.0);
uniform vec3 pal_4=vec3(2.0,3.0,3.0);
float seg(vec2 p,vec2 a,vec2 b){
 vec2 d=b-a;
 return length(p-a-d*clamp(dot(p-a,d)/max(dot(d,d),.001),0.0,1.0));
}
void fragment(){
 vec2 cell=floor(UV*res);
 vec2 p=((cell+.5)/res-.5)*2.0;
 float t=floor(phase*12.0)/12.0;
 float a=atan(p.y,p.x);
 float turn=fract(a/6.283185+1.0);
 float radial=length(p);
 float d=9.0;
 float order=turn;
 if(motif==0){
  vec2 p0=vec2(-.75,-.42),p1=vec2(.52,-.69),p2=vec2(.73,.52),p3=vec2(-.46,.71);
  d=min(min(seg(p,p0,p1),seg(p,p1,p2)),min(seg(p,p2,p3),seg(p,p3,p0)));
  d=min(d,min(abs(p.x)+abs(p.y),abs(p.x-.52)+abs(p.y+.69))*.35);
 }else if(motif==1){
  d=abs(radial-.74);
  if(length(p-vec2(.40+.12*sin(t*.65),0))<.78)discard;
  order=(p.y+1.0)*.5;
 }else if(motif==2){
  float y=p.y+.12*sin(p.x*7.0-t*2.1);
  d=min(abs(y+.47),min(abs(y),abs(y-.47)));
  if(abs(p.x)>.88)discard;
  order=(p.x+1.0)*.5;
 }else if(motif==3){
  for(int i=0;i<6;i++){
   float ang=float(i)*1.047198;
   vec2 v=vec2(cos(ang),sin(ang));
   d=min(d,seg(p,v*.48,v*.86));
  }
 }else if(motif==4){
  for(int i=0;i<6;i++){
   float ang=float(i)*1.047198;
   vec2 v=vec2(cos(ang),sin(ang));
   vec2 n=vec2(-v.y,v.x);
   d=min(d,seg(p,v*.74-n*.12,v*.74+n*.12));
  }
 }else if(motif==5){
  d=min(seg(p,vec2(-.64,-.87),vec2(-.64,.87)),seg(p,vec2(.64,-.87),vec2(.64,.87)));
  float tick=abs(fract(p.y*4.0-t*.5)-.5);
  if(tick<.10)d=min(d,min(abs(p.x-.75),abs(p.x+.75)));
  order=(p.y+1.0)*.5;
 }else if(motif==6){
  d=min(abs(max(abs(p.x),abs(p.y))-.70),abs(abs(p.x)-abs(p.y)));
  if(radial<.40 || radial>.90)discard;
  order=(p.x+1.0)*.5;
 }else{
  for(int i=0;i<8;i++){
   float ang=float(i)*.785398;
   vec2 v=vec2(cos(ang),sin(ang));
   vec2 n=vec2(-v.y,v.x);
   vec2 q=p-v*.74;
   float x=dot(q,n),y=dot(q,v);
   d=min(d,min(abs(x)+max(abs(y)-.12,0.0),abs(y)+max(abs(x)-.09,0.0)));
  }
 }
 if(d>.040 || order>open || order<close || close>=.999)discard;
 float intensity=.28+.45*(1.0-clamp(d/.040,0.0,1.0))+.12*sin(t*4.0-turn*13.0+seed);
 ALBEDO=px_ramp(intensity,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
