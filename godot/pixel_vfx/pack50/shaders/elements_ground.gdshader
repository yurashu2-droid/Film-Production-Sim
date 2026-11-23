shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
uniform float phase = 0.0;
uniform float sweep = 0.0;
uniform float seed = 0.0;
uniform float radius = 0.75;
uniform int mode = 0;
void fragment() {
 vec2 cell = floor(UV*64.0);
 vec2 p = ((cell+0.5)/64.0-0.5)*2.0;
 float r = length(p);
 float a = atan(p.y,p.x);
 float t = floor(phase*12.0)/12.0;
 float sector = fract(a/6.28318+t*0.065+seed);
 if (sector < sweep || r > 0.98) discard;
 float shape = abs(r-radius);
 if (mode == 1) shape = abs(r-radius-sin(a*5.0+t*3.0)*0.045);
 if (mode == 2) shape = abs(r-radius) + step(0.35,fract(a*1.9098+t*0.17))*0.11;
 if (mode == 3) shape = r-0.62-sin(a*7.0+seed)*0.10;
 if (mode == 4) shape = abs(sin(a*5.0+r*8.0+seed))*0.2+max(r-0.82,0.0);
 if (mode == 5) {
  float cross_shape=min(max(abs(p.x)-0.045,abs(p.y)-0.27),max(abs(p.y)-0.045,abs(p.x)-0.27));
  shape=min(abs(r-radius),cross_shape);
 }
 // These are deliberately non-circular footprints of force/deposition.
 if (mode == 6) shape=abs(p.y-sin(p.x*5.0+t*1.3+seed)*0.06)+abs(p.x)*0.035-0.065;
 if (mode == 7) shape=abs(p.y-p.x*p.x*0.38)-0.11+(px_fbm(p*9.0+seed)-0.5)*0.23;
 if (mode == 8) shape=length(p*vec2(0.7,1.5))-0.61+(px_fbm(p*8.0+vec2(t*0.12,seed))-0.5)*0.33;
 if (mode == 9) shape=abs(p.y-sin(p.x*3.0+t*0.9+seed)*0.22)-0.025;
 if (mode == 10) shape=min(abs(p.x-0.22),abs(p.x+0.22))+max(abs(p.y)-0.22,0.0)-0.035;
 if (mode == 11) shape=abs(sin(a*3.0+seed))*0.13+max(r-0.62,0.0)+max(0.24-r,0.0)-0.04;
 if (mode == 12) shape=abs(p.y-p.x*0.28-sin(p.x*4.0-t)*0.12)-0.026;
 if (shape > (mode == 3 || mode >= 6 ? 0.0 : 0.038)) discard;
 if (mode >= 6 && mode != 8 && px_fbm(p*18.0+seed)<0.30) discard;
 float lit = mode == 3 || mode == 8 ? 0.14+0.2*sin(a*3.0+r*7.0) : 0.34+0.25*sin(a*4.0-r*7.0-t*3.0);
 ALBEDO = px_ramp(lit,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}
