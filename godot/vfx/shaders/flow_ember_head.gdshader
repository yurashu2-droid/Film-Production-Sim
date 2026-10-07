shader_type spatial;
// Projectile orb's forward core + flowing rear aura, clocked by the owning effect.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform float phase = 0.0;
uniform float cool = 0.0;
uniform bool core = false;
varying vec3 local_pos;
void vertex(){ local_pos=VERTEX; }
void fragment(){
 float rim=1.0-abs(dot(normalize(NORMAL),normalize(VIEW)));
 float back=smoothstep(-0.5,0.5,local_pos.z);
 vec2 uv=vec2(atan(local_pos.x,local_pos.y)/6.2832*2.0,local_pos.z*0.7-phase*3.0);
 vec3 field=texture(noise_texture,uv).rgb;
 // Distort the trailing material with vector flow; leave the leading core anchored.
 float n=texture(noise_texture,uv+(field.rg*2.0-1.0)*back*0.18).b;
 vec3 main=mix(vec3(7,2,0.25),vec3(2.0,0.17,0.015),cool);
 vec3 hot=mix(vec3(10,8.5,5),vec3(3.5,0.4,0.035),cool);
 ALBEDO=core ? hot : main;
 // Flowing density modulation, never thresholded into noise holes.
 float density=(0.5+0.5*n)*(0.3+0.65*rim)*(1.0-back*0.55);
 ALPHA=(core ? 1.0 : density)*(1.0-smoothstep(0.7,1.0,cool));
}
