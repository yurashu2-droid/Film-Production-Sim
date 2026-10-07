shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D spiral : repeat_disable, filter_linear_mipmap;
uniform sampler2D flame : repeat_enable, filter_linear_mipmap;
uniform float phase=0.0;
uniform float born=0.0;
uniform float stop_time=2.65;
uniform float duration=1.0;
uniform float seed=0.0;
uniform float speed=0.5;
uniform float arms=3.0;
uniform float radial_size=3.0;
uniform vec3 shade=vec3(0.65,0.018,0.002);
uniform vec3 hot=vec3(2.6,0.32,0.018);
void vertex() {
 VERTEX.xz*=radial_size;
}
void fragment() {
 vec2 p=(UV-0.5)*2.0;
 float r=length(p);
 float a=atan(p.y,p.x);
 float birth=smoothstep(0.0,0.3,phase-born-r*0.1);
 float close=clamp((phase-stop_time)/duration,0.0,1.0);
 float phi=a-phase*speed+seed;
 vec2 spun=mat2(vec2(cos(phi-a),sin(phi-a)),vec2(-sin(phi-a),cos(phi-a)))*p;
 float art=texture(spiral,spun*0.46+0.5).r;
 float spiral_phase=a*arms-r*8.5-phase*speed*arms+seed*6.0;
 float arm=pow(max(0.0,0.5+0.5*sin(spiral_phase)),5.0);
 float width=(0.07+arm*0.7)*(1.0-close*0.9);
 // Broad tongues feed inward along the curved arms; no polished solid stamp.
 float fuel=texture(flame,vec2(a/TAU*1.4-r*0.75-phase*speed*0.22+seed,r*0.72+phase*0.42)).r;
 float density=(art*width+arm*0.26)*smoothstep(0.18,0.54,fuel);
 float rim=1.0-smoothstep(0.68,0.99,r);
 float hole=smoothstep(0.08,0.23,r);
 float sweep=1.0;
 // Each component has a different exit: winding tighter, angular wipe, radial drain.
 if(seed<0.5) {
  density*=1.0-smoothstep(0.15,1.0,close+r*0.17);
 } else if(seed<1.5) {
  float angular=fract(a/TAU+phase*0.11+seed);
  sweep=smoothstep(close,close+0.10,angular);
 } else {
  rim*=smoothstep(close,close+0.14,r);
 }
 float visible=density*rim*hole*sweep*birth*(1.0-close);
 if(visible<0.004) { discard; }
 vec3 color=mix(shade,hot,smoothstep(0.16,0.62,visible));
 color=mix(color,vec3(0.23,0.006,0.001),close);
 ALBEDO=color;
 ALPHA=min(0.65,visible*1.6);
}
