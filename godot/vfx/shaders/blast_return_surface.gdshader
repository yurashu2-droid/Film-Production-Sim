shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float phase=0.0;
uniform float heat=1.0;
uniform float return_amount=0.0;
uniform bool stem=false;
varying vec3 wn;
void vertex(){
 float a=atan(VERTEX.z,VERTEX.x);
 float v=UV.y;
 float retract=return_amount;
 if(stem){
  float neck=1.0-retract*smoothstep(0.35,0.95,v);
  VERTEX.xz*=max(0.01,neck*neck);
  VERTEX.x+=sin(v*6.0+phase*3.0)*0.12*v;
  VERTEX.y=v*(1.0-0.65*retract)+0.25*retract*v*v;
 }else{
  float tongue=sin(a*9.0+v*8.0-phase*4.0);
  float shoulder=sin(v*3.14159);
  VERTEX.xz*=max(0.01,1.0-retract*(0.55+0.45*v));
  VERTEX.y=(v-0.5)*0.9*(1.0-retract)+0.08*tongue*shoulder*(1.0-retract);
  VERTEX.x+=0.13*sin(v*5.0+phase*2.0)*shoulder*(1.0-retract);
 }
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float band=UV.y+0.1*sin(UV.x*57.0+phase*3.0);
 vec3 hot=band>0.44?vec3(9.0,7.5,3.8):(band>0.25?vec3(6,3.3,0.12):vec3(3.8,0.5,0.045));
 vec3 yellow=vec3(5.0,2.0,0.09), orange=vec3(2.9,0.42,0.025), red=vec3(0.65,0.045,0.012);
 vec3 cool=heat>0.65?mix(yellow,hot,(heat-0.65)/0.35):(heat>0.25?mix(orange,yellow,(heat-0.25)/0.4):mix(red,orange,heat/0.25));
 ALBEDO=cool*(dot(wn,normalize(vec3(-0.4,0.8,0.5)))>-0.25?1.0:0.65);
}
