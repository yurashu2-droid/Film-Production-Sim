shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform float phase=0.0;
uniform float layer=0.0;
uniform float stream=0.0;
uniform float mode=0.0;
uniform float size=1.0;
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
float travel(float v){return mode<.5?.13+sqrt(v*3.1/4.9):.925+v*.65;}
void vertex(){
 float u=UV.x;float v=UV.y;
 float t=floor(phase*12.0)/12.0;
 float e=t-travel(v);
 float shoulder=exp(-pow((e-.65-stream*.11)/.18,2.0))+exp(-pow((e-1.65-stream*.07)/.24,2.0));
 float belly=exp(-pow((e-.86-stream*.11)/.25,2.0))+exp(-pow((e-1.85-stream*.07)/.28,2.0));
 float breadth=(.35-layer*.105)*(1.0+shoulder*.55-belly*.18);
 float center=(stream-1.0)*.78+sin(e*3.0+stream*1.7)*.13;
 vec3 p;
 if(mode<.5){
  float x=center+(u-.5)*breadth*2.0+(shoulder-belly*.55)*.14;
  float y=3.15-v*3.12;
  float z=sin(e*2.4+v*4.0+stream)*.17+layer*.075;
  p=vec3(x,y,z);
 }else{
  float direction=(stream-1.0)*.72;
  float run=v*(1.40+shoulder*.34);
  float x=center+direction*run+(u-.5)*breadth*(1.0+v*.8);
  float y=.045+sin(v*PI)*(.35+shoulder*.18)*(1.0-layer*.20);
  float z=run+sin(e*2.4+stream)*.12+layer*.055;
  p=vec3(x,y,z);
 }
 VERTEX=floor(p/.055+.5)*.055*size;
}
void fragment(){
 vec2 resolution=mode<.5?vec2(14,64):vec2(14,38);
 vec2 cell=floor(UV*resolution);
 vec2 p=(cell+.5)/resolution;
 float t=floor(phase*12.0)/12.0;
 float e=t-travel(p.y);
 if(e<stream*.12+layer*.035||e>2.70-layer*.10)discard;
 float n=px_noise(vec2(cell.x*.31+stream*2.3+layer,cell.y*.20-e*2.4));
 float width=abs(p.x-.5)*2.0;
 if(n<.28+width*.26||px_bayer(cell)>.80-width*.30)discard;
 float tone=layer<.5?.06+n*.20:(layer<1.5?.35+n*.24:.68+n*.30);
 ALBEDO=px_ramp(tone,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
