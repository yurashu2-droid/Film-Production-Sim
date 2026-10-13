shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float phase = 0.0;
uniform float layer = 0.0;
uniform float seed = 0.0;
uniform float distance_start = 0.0;
uniform float distance_end = 1.0;
void fragment(){
 float d=mix(distance_start,distance_end,UV.y);
 float t=phase-layer*.065;
 float e=0.0;
 for(int k=0;k<4;k++){
  float cue=k==0?.15:(k==1?1.05:(k==2?2.2:3.72));
  float since=t-cue-d*1.08;
  // White moving front, amber conductive body, slower corona: causal supply windows.
  float duration=layer<.5?.34:(layer<1.5?.28:.18);
  float pulse=smoothstep(-.09,.03,since)*(1.0-smoothstep(duration,duration+.12,since));
  e=max(e,pulse);
 }
 float a=UV.x*6.283185;
 float strand=sin(a*(layer<.5?3.0:2.0)+d*24.0-phase*(3.0+layer)+seed);
 float density=smoothstep(layer<.5?.48:(layer<1.5?.20:-.65),.98,strand);
 float rim=pow(max(0.0,1.0-abs(dot(NORMAL,VIEW))),.6);
 vec3 color=layer<.5?vec3(.85,.23,.035):(layer<1.5?vec3(2.8,1.2,.14):vec3(4.5,3.8,1.9));
 ALBEDO=color;
 ALPHA=e*density*(layer<.5?.22:(layer<1.5?.6:.85))*(.4+.6*rim);
}
