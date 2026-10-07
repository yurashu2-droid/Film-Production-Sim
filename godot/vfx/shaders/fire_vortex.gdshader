shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Sparse travelling flame sheets, not an opaque funnel with a moving decoration.
// LeLu FirePanningCyl45 = flame silhouette; marble = low-amplitude flow warp.
uniform sampler2D flame : repeat_enable, filter_linear_mipmap;
uniform sampler2D warp_map : repeat_enable, filter_linear_mipmap;
uniform float phase = 0.0;
uniform float born = 0.0;
uniform float stop_time = 2.65;
uniform float radius = 1.0;
uniform float height = 5.0;
uniform float seed = 0.0;
uniform float rotation_speed = 0.45;
uniform float climb_speed = 0.36;
uniform float coverage = 0.44;
uniform float shear = -1.1;
uniform bool root_flow = false;
uniform vec3 shade = vec3(1.0,0.025,0.005);
uniform vec3 hot = vec3(3.0,0.3,0.015);
varying float material_height;

void vertex() {
 float v = UV.y;
 float a = UV.x*TAU;
 float pressure = 0.13*sin(v*10.0-phase*5.1) + 0.07*sin(a*2.0-v*8.0+phase*3.1+seed);
 float angle = a + v*0.17*sin(phase*1.4);
 float r = length(VERTEX.xz)*radius*(1.0+pressure);
 float y = v*height;
 if(root_flow) {
  float close = smoothstep(stop_time,stop_time+0.85,phase);
  float beat = 0.12*sin(phase*6.2-v*3.5)+0.15*exp(-pow((phase-0.4)*5.0,2.0));
  r *= 1.0+beat*(1.0-v);
  y *= 1.0-close*v;
  r = mix(r,r*(1.0-0.68*close*v),close);
  y += sin(a*3.0-phase*4.1)*0.1*v;
 } else {
  // All sheets share a wandering axis; shoulders travel up at different phases.
  y += sin(a*3.0-v*8.0+phase*4.0+seed)*0.10*v;
  // The departing tongue narrows locally and rises, rather than leaving a wide cap.
  float depart=smoothstep(0.0,0.65,phase-stop_time-v*0.72);
  r *= 1.0-0.76*depart;
  y += depart*(0.35+v*0.75);
 }
 VERTEX = vec3(cos(angle)*r,y,sin(angle)*r);
 if(!root_flow) {
  VERTEX.x += sin(phase*1.35-v*2.1)*0.28*v;
  VERTEX.z += cos(phase*1.1-v*2.7)*0.23*v;
 }
 material_height=v;
}

void fragment() {
 float v=material_height;
 float feed_delay = v*(root_flow ? 0.15 : 0.58);
 float birth = smoothstep(0.0,0.19,phase-born-feed_delay);
 float after = phase-stop_time;
 // Supply front travels up the existing flow. No age-dependent noise threshold.
 float trailing = root_flow ? (1.0-smoothstep(0.0,0.85,after+v*0.16))
                            : (1.0-smoothstep(0.0,0.30,after-v*0.85));
 if(birth*trailing<0.015) { discard; }
 vec2 fluid=vec2(UV.x+shear*v-rotation_speed*phase+seed,v*0.91-climb_speed*phase);
 float bend=textureLod(warp_map,vec2(UV.x*0.55+seed,v*0.48-phase*0.13),3.0).r-0.5;
 fluid.x += bend*0.07*(0.4+v);
 float density=texture(flame,fluid).r;
 // Pointed tips have varying heights around the circumference, not a cut tube rim.
 float crest=0.78+0.22*textureLod(warp_map,vec2(UV.x*1.0+seed,phase*0.21),3.0).r;
 float taper=1.0-smoothstep(crest-0.22,crest,v);
 float edge=smoothstep(coverage,coverage+0.20,density)*taper;
 if(edge<0.004) { discard; }
 float cooling=root_flow ? smoothstep(0.0,0.65,after) : smoothstep(0.0,0.50,after-v*0.8);
 float heat=smoothstep(0.28,0.80,density)*(0.72+0.28*sin(v*8.0-phase*3.2+seed));
 vec3 color=mix(shade,hot,heat);
 color=mix(color,vec3(0.75,0.035,0.003),cooling*0.70);
 // Progressive material taper / cooling; spatial flow mask remains unchanged.
 ALBEDO=color;
 ALPHA=edge*birth*trailing*(root_flow ? 0.60 : 0.38);
}
