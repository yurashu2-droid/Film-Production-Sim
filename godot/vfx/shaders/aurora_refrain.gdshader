shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float phase=0.0;
uniform float layer=0.0;
uniform float size=1.0;
uniform vec3 shade=vec3(0.04,1.6,0.7);
uniform vec3 hot=vec3(0.6,4.2,2.0);

// A sharp front followed by a much slower response. Delay is distance along the curtain.
float strike(float t, float arrival, float strength, float decay) {
 float d=t-arrival;
 float head=exp(-pow(d/0.11,2.0));
 float follow=smoothstep(-0.03,0.07,d)*exp(-max(0.0,d)*decay)*0.38;
 return (head+follow)*strength;
}
vec3 waves(float t, float u) {
 float one=strike(t,0.72+u*0.46,0.85,3.7);
 float two=strike(t,1.20+(1.0-u)*0.46,0.52,4.5);
 float three=strike(t,2.18+(0.5-abs(u-0.5))*0.70,1.38,1.65);
 return vec3(one,two,three);
}
// The last white excitation collects inward, then a weaker green response carries it
// outward along the folds. The receiving outer veil subsequently drains upward.
float core_arrival(float u) { return 3.12+(0.5-abs(u-0.5))*1.0; }
float green_arrival(float u) {
 return 3.57+(u<0.5 ? (0.5-u)*0.68 : (u-0.5)*1.68);
}
vec2 departure(float t, float u) {
 return vec2(strike(t,core_arrival(u),0.65,3.7),
             strike(t,green_arrival(u),0.85,3.1)
             +strike(t-0.12,green_arrival(u),0.22,3.1));
}
void vertex() {
 float u=UV.x;
 float v=UV.y;
 float t=phase-layer*0.045;
 vec3 wave=waves(t,u);
 vec3 chase=waves(t-0.14,u);
 float swell=wave.x+wave.y+wave.z;
 float grow=smoothstep(0.02,0.55,t);
 float edge=pow(max(0.0,sin(u*PI)),0.45);
 float height=(1.12+wave.x*0.8+wave.y*0.5+wave.z*1.25+chase.z*0.40)*edge;
 height*=mix(1.35,0.76,layer*0.5);
 float x=(u-0.5)*6.6+sin(u*8.0-t*0.65)*0.70*v*v;
 // A passing front moves the shoulder sideways; the delayed fold pulls a neck behind it.
 x+=(wave.x-wave.y+0.45*wave.z-0.55*chase.z)*0.62*(0.3+v)*edge;
 float bottom=0.85+0.30*sin(u*TAU-t*0.55)+0.16*swell;
 float y=bottom+v*height*grow;
 float folds=sin(u*TAU*1.35-t*0.48)*1.10;
 folds+=(wave.x-wave.y+wave.z*0.7-chase.z*0.5)*0.85;
 float z=folds*(0.3+v*0.7)+(1.0-layer)*0.26;
 z+=sin(u*21.0-t*0.8+layer*0.55)*0.08*v;
 vec2 leaving=departure(t,u);
 if(layer<0.5) {
  // Drain the foot while the surviving upper material stretches and rises.
  float lift=smoothstep(3.90,4.80,t);
  y+=lift*(0.20+v*2.2);
  x+=sin(u*12.0-t*0.7)*0.18*lift*v;
 } else if(layer<1.5) {
  // A moving shoulder followed by a neck rolls each fold toward its own end.
  float behind=departure(t-0.16,u).y;
  float direction=sign(u-0.5);
  float released=max(0.0,t-green_arrival(u));
  y+=leaving.y*v*0.50+released*0.65;
  x+=direction*(released*3.2*(0.55+v*0.45)+v*v*0.45*leaving.y);
  z+=direction*(leaving.y-behind*0.65)*(0.9+v*0.8);
 } else {
  x-=sign(u-0.5)*leaving.x*0.24*(1.0-v);
  y+=leaving.x*v*0.35;
  z+=leaving.x*0.30;
 }
 VERTEX=vec3(x,y,z)*size;
}
void fragment() {
 float u=UV.x;
 float v=UV.y;
 float t=phase-layer*0.045;
 vec3 wave=waves(t-v*0.12,u);
 float energy=wave.x+wave.y+wave.z;
 vec2 leaving=departure(t-v*0.05,u);
 float born=smoothstep(0.0,0.5,t-abs(u-0.5)*0.22-v*0.12);
 float fringe=u*17.0+sin(u*9.0-t*0.62)*1.8+v*1.6+layer*0.63;
 float curtain=0.06+0.94*smoothstep(0.10,0.72,0.5+0.5*sin(fringe));
 float floor_edge=smoothstep(0.0,0.09,v);
 float height_edge=1.0-smoothstep(0.65,1.0,v);
 float side_edge=smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.88,1.0,u));
 if(layer>0.5 && layer<1.5) {
  // An outgoing excitation has no hard sheet edge. Its thickness unbinds while
  // the curved flow leaves the fold; stop emitting before the pointed end cap.
  float unbound=smoothstep(3.46,3.72,t);
  floor_edge=mix(floor_edge,smoothstep(0.02,0.55,v),unbound);
  height_edge=mix(height_edge,1.0-smoothstep(0.25,0.98,v),unbound);
  float end_supply=smoothstep(0.04,0.24,u)*(1.0-smoothstep(0.76,0.96,u));
  side_edge*=mix(1.0,end_supply,unbound);
 }
 float density=curtain*floor_edge*height_edge*side_edge*exp(-v*1.1);
 density*=0.88+0.12*sin(u*88.0+v*0.5-t*0.65);
 if(layer>1.5) {
  density*=exp(-v*4.5);
  density*=smoothstep(0.04,0.23,u)*(1.0-smoothstep(0.77,0.96,u));
 }
 float exit=1.0;
 float return_energy=0.0;
 if(layer<0.5) {
  float front=max(0.0,(t-3.95)/0.70);
  float draining=smoothstep(3.86,3.98,t);
  exit=mix(1.0,smoothstep(front-0.12,front+0.12,v),draining);
  float rising=exp(-pow((v-front-0.16)/0.21,2.0));
  return_energy=rising*smoothstep(3.90,4.06,t)*0.42;
 } else if(layer<1.5) {
  exit=1.0-smoothstep(green_arrival(u)+0.12,green_arrival(u)+0.40,t);
  return_energy=leaving.y;
 } else {
  exit=1.0-smoothstep(core_arrival(u)+0.10,core_arrival(u)+0.38,t);
  return_energy=leaving.x;
 }
 float glow=0.16+(energy+return_energy)*0.80;
 vec3 color=mix(shade,hot,clamp((energy+return_energy)*0.70,0.0,1.0));
 if(layer<0.5) color=mix(color,vec3(0.34,0.08,0.60),v*0.60);
 ALBEDO=color;
 float optical_density=layer>1.5 ? 0.34 : mix(0.26,0.43,layer);
 ALPHA=density*born*exit*glow*optical_density;
}
