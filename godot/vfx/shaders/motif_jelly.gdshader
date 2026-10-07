shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float age = 0.0;
uniform float size = 1.0;
uniform int kind = 0;
varying float fold_value;
float pressure(float t, float v) {
 float phase = t * 5.1 - v * 3.8;
 return sin(phase) * 0.16 + exp(-pow(abs((t - 0.55 - v * 0.22) * 5.0), 2.0)) * 0.35;
}
vec3 membrane(float u, float v, float t) {
 float th = u * TAU;
 float f = smoothstep(2.65,3.65,t);
 float birth = smoothstep(0.0,0.48,t-v*0.14);
 float p = pressure(t,v);
 float scallop = sin(th*3.0 + v*3.4-t*1.8) * pow(v,3.0);
 float radial = sin(v * 1.75) * (1.02+p) + scallop*0.20;
 // A travelling neck and rolled skirt alter local curvature, not object scale.
 radial += 0.19*sin(v*8.5-t*5.1+th*2.0)*pow(v,2.0);
 radial *= 1.2 * birth * (1.0-f*0.78);
 float curl = sin(v*3.14159)*f*0.55;
 float y = 3.4 - (1.0-cos(v*1.8))*1.12 + p*(1.0-v)*0.5;
 y += scallop*0.28 + f*(0.8+v*1.2) + curl;
 float sway = sin(t*1.7-v*1.9)*0.22*v;
 return vec3(cos(th)*radial+sway,sin(th*2.0)*v*0.07+y,sin(th)*radial*0.72);
}
void vertex() {
 float u = UV.x;
 float v = UV.y;
 fold_value = smoothstep(2.65,3.65,age);
 if(kind == 0) {
  VERTEX = membrane(u,v,age)*size;
 } else {
  // Seven strips, with a true delayed history of their moving attachment.
  float lane = min(floor(u*7.0),6.0);
  float side = fract(u*7.0)*2.0-1.0;
  float a = (lane+0.35)/7.0;
  float f = smoothstep(2.8+lane*0.025,3.7,age);
  vec3 root = membrane(a,0.91, max(0.0,age-v*0.36));
  float length = (1.5+0.3*sin(lane*2.0)) * smoothstep(0.18,0.85,age) * (1.0-f);
  float turn = age*3.4-v*5.5+lane*1.2;
  vec3 p = root + vec3(sin(turn)*v*0.28,-v*length,cos(turn*0.7)*v*0.2);
  float width = (0.075+0.035*sin(v*8.0-age*4.0+lane)) * (1.0-v*0.85)*(1.0-f);
  p.x += side*width;
  p.z += side*width*cos(turn);
  VERTEX = p*size;
 }
}
void fragment() {
 float v = UV.y;
 float fade = smoothstep(0.0,0.35,age) * (1.0-smoothstep(3.05,3.7,age));
 if(kind == 0) {
  float linepos = UV.x*8.0 + 0.045*sin(v*9.0-age*4.0);
  float comb = exp(-pow(abs(sin(linepos*3.14159)*4.5),2.0))*smoothstep(0.04,0.18,v)*(1.0-smoothstep(2.9,3.5,age));
  float teeth = 0.4+0.6*pow(0.5+0.5*sin(v*125.0-age*16.0),3.0);
  float wave = 0.12+0.88*pow(0.5+0.5*sin(v*13.0-age*7.0+UV.x*2.0),2.0);
  vec3 rainbow = 0.5+0.5*cos(vec3(0.0,2.094,4.188)+v*16.0-age*5.4+UV.x*6.0);
  rainbow = pow(max(rainbow,vec3(0.0)), vec3(2.5));
  float rim = pow(v,12.0)*0.65;
  float fold = 0.5+0.5*sin(v*16.0-age*5.0+UV.x*12.0);
  vec3 tissue = mix(vec3(0.07,0.3,0.42),vec3(0.3,0.65,0.65),fold);
  ALBEDO = tissue + rainbow*comb*teeth*wave*2.4 + vec3(0.15,0.6,0.7)*rim;
  EMISSION = rainbow*comb*teeth*wave*1.6;
  ALPHA = (0.14+fold*0.1+rim*0.3+comb*teeth*wave*0.8)*fade*smoothstep(0.07,0.18,v);
 } else {
  float edge = pow(max(0.0,1.0-abs(fract(UV.x*7.0)*2.0-1.0)),0.7);
  ALBEDO = vec3(0.18,0.52,0.6) + vec3(0.5,0.22,0.42)*sin(v*7.0-age*2.0)*0.2;
  EMISSION = vec3(0.02,0.08,0.1);
  ALPHA = edge*(1.0-v)*0.6*fade*(1.0-smoothstep(2.95,3.65,age));
 }
}







