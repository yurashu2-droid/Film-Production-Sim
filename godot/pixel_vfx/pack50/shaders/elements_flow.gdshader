shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://pixel_vfx/shaders/px_common.gdshaderinc"
uniform vec3 pal_0;
uniform vec3 pal_1;
uniform vec3 pal_2;
uniform vec3 pal_3;
uniform vec3 pal_4;
uniform float phase = 0.0;
uniform float layer = 0.0;
uniform float seed = 0.0;
uniform float grid = 36.0;
uniform float density = 0.5;
uniform float heat = 1.0;
uniform bool granular = false;
void fragment() {
 vec2 cell = floor(UV * vec2(grid,grid * 1.5));
 vec2 p = (cell + 0.5) / vec2(grid,grid * 1.5);
 float t = floor(phase*12.0)/12.0;
 // Permanently open currents, rather than lifetime noise dissolution.
 float drift = p.x*5.0 + p.y*3.1-t*(0.6+layer*0.21)+seed;
 float current = sin(drift*6.28318)*0.34+sin(p.y*27.0-t*4.0+seed)*0.16;
 float grain = px_fbm(vec2(p.x*7.0+p.y*4.0-t,p.y*8.0-t*1.7+seed));
 float v = current+grain*0.54;
 if(granular) {
  v=grain*.85+current*.20;
  if(px_hash(cell+vec2(seed,0.0))<.70) discard;
  if(v<.42) discard;
 } else if (v < 0.59-density*0.24) discard;
 float rim = min(p.y,1.0-p.y)*7.0;
 if (rim < px_bayer(cell)*0.85) discard;
 float lit = clamp((v-0.26)*1.05,0.0,0.91);
 lit += layer*0.17*smoothstep(0.66,0.91,p.y);
 vec3 col = px_ramp(lit,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
 ALBEDO = col * heat;
}
