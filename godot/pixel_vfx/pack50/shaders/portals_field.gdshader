shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
// Physical depth belongs to the five meshes. These cells are never billboards.
uniform float res = 56.0;
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform int shape = 0;
uniform int mode = 0;
uniform float layer = 0.0;
uniform float open = 0.0;
uniform float close = 0.0;
uniform float start_angle = 0.0;
uniform float slice_start = 0.0;
uniform float slice_end = 1.0;
uniform int exit_mode = 0;
uniform float inner = 0.48;
uniform float outer = 0.98;
uniform float spin = 1.0;
uniform float depth_curve = 0.0;
uniform vec3 pal_0 = vec3(0.04,0.01,0.14);
uniform vec3 pal_1 = vec3(0.2,0.04,0.7);
uniform vec3 pal_2 = vec3(0.8,0.3,2.0);
uniform vec3 pal_3 = vec3(1.3,2.3,4.0);
uniform vec3 pal_4 = vec3(5.0,7.0,8.0);

void vertex() {
 vec2 p=UV*2.0-1.0;
 float t=floor(phase*12.0)/12.0;
 VERTEX.z += depth_curve*(p.x*p.x*.60+p.y*p.y*.40);
 VERTEX.z += depth_curve*.10*sin(p.y*5.0-t*1.6+layer*.8);
}

float shape_metric(vec2 p, float a, float t) {
 float r=length(p);
 if (shape==1) { // traveling eclipse bite: the foreground is a crescent, rear rings remain
  r += 0.055*sin(a*3.0-t*1.7+layer);
 } else if (shape==2) {
  r += 0.09*sin(a*3.0-t*2.1+layer*0.5)+0.055*sin(a*7.0+t+layer);
 } else if (shape==3) {
  float n=6.0;
  r *= cos(mod(a+3.14159/n,6.28318/n)-3.14159/n)/cos(3.14159/n);
  r += 0.05*sin(a*6.0+t*1.4+layer);
 } else if (shape==4) {
  r *= cos(mod(a+0.523599,1.047198)-0.523599)/0.866025;
 } else if (shape==5) {
  r = max(abs(p.x)*1.12,abs(p.y)*0.92);
  r += 0.022*sin(p.y*14.0+t*3.0+layer);
 } else if (shape==9) {
  r=max(abs(p.x)*1.15,abs(p.y+0.12)*1.05);
  r=max(r,(p.y+0.60*abs(p.x))*1.12);
 } else if (shape==6) {
  r += 0.07*cos(a*8.0+t*0.8+layer*0.35);
 } else if (shape==7) {
  r = length(vec2(p.x*3.4,p.y*0.84));
  r += 0.06*sin(p.y*12.0-t*3.0+layer);
 } else if (shape==8) {
  r = pow(pow(abs(p.x),0.9)+pow(abs(p.y),0.9),1.0/0.9);
 }
 return r;
}

void fragment() {
 vec2 cell=floor(UV*res);
 vec2 p=((cell+0.5)/res-0.5)*2.0;
 float t=floor(phase*12.0)/12.0;
 float a=atan(p.y,p.x);
 float turn=fract(a/6.283185+1.0);
 float r=shape_metric(p,a,t);
 float order=fract(turn-start_angle+1.0);
 if(turn<slice_start || turn>=slice_end) discard;
 // Opening and closing move a leading edge. No lifetime noise or radial contraction.
 float wipe=order;
 if(exit_mode==1) wipe=(p.y+1.0)*0.5;
 if(exit_mode==2) wipe=(p.x+1.0)*0.5;
 if(exit_mode==3) wipe=fract(turn*6.0+layer*0.13);
 if(exit_mode==4) wipe=(1.0-p.x)*0.5;
 if(exit_mode==5) wipe=fract(turn*8.0+layer*0.13);
 if(exit_mode==6) wipe=(p.x+p.y+2.0)*0.25;
 float opening_order = mode==1 ? (1.0-p.y)*0.5 : order;
 if(mode==0 && exit_mode==1) opening_order=(1.0-p.y)*0.5;
 if(mode==0 && exit_mode==2) opening_order=(p.x+1.0)*0.5;
 if(mode==0 && shape==9) opening_order=(1.0-p.y)*0.5;
 if(opening_order>open || wipe<close || close>=0.999) discard;
 if(mode==1) {
  if(r>outer) discard;
  vec3 dark=pal_0*0.12;
  float sky=px_hash(cell+floor(t*2.0)+seed*7.0);
  float stars=step(0.994,sky);
  if(shape==5) stars=step(0.985,sky)*step(0.5,fract(cell.x/4.0+t*0.4));
  if(shape==7) stars=step(0.975,sky)*step(0.45,fract(cell.y/6.0-t));
  ALBEDO=mix(dark,pal_2*0.7,stars);
 } else {
  if(r<inner || r>outer) discard;
  float k=(r-inner)/max(outer-inner,0.001);
  float drift=t*spin;
  float v=px_fbm(vec2(turn*13.0+r*4.0-drift, r*8.0+seed));
  float stream=sin(a*(4.0+mod(layer,3.0))+r*14.0-drift*3.0);
  float gaps=fract(turn*(7.0+layer*2.0)-drift*0.16+layer*0.173);
  float mask=v+0.2*stream;
  if(shape==4) mask+=0.22*step(0.77,fract(turn*6.0));
  if(shape==5) mask+=0.18*step(0.55,fract((p.x+p.y)*9.0-drift));
  if(shape==6) mask+=0.25*step(0.5,fract(turn*16.0+floor(r*12.0)*0.37));
  if(shape==8) mask+=0.20*step(0.6,fract((p.x-p.y)*10.0));
  if(shape==1 && layer<4.0 && length(p-vec2(0.42+0.10*sin(t*0.8),0.06))<0.89) discard;
  if(mask<0.27 || gaps<0.08) discard;
  float brightness=clamp((mask-0.24)*1.45+0.18*(1.0-k),0.0,1.0);
  ALBEDO=px_ramp(brightness,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
 }
}
