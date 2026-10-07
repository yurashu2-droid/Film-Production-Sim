shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform float phase=0.0;
uniform float heat=1.0;
uniform float stream=0.0;
uniform float thin=1.0;
varying vec3 nw;
void vertex(){
 float a=atan(VERTEX.z,VERTEX.x);
 float h=UV.y;
 VERTEX.xz*=thin * mix(1.0, 0.72+0.27*cos(h*18.85-phase*3.0),stream);
 VERTEX.x+=stream*0.12*sin(h*6.0-phase*2.0);
 VERTEX.y+=stream*0.12*sin(h*8.0-phase*3.0);
 nw=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float n=texture(noise_texture,UV*vec2(17.0,1.1)+vec2(0.0,-phase*0.6)).r;
 float stripe=UV.y-(0.08+min(phase,1.8)*0.4+0.13*sin(UV.x*57.0+phase*2.0)+n*0.32);
 vec3 hot=stripe>0.12?vec3(9.0,7.5,3.8):(stripe>-0.07?vec3(6.0,3.3,0.12):vec3(3.8,0.5,0.045));
 float lit=dot(normalize(nw),normalize(vec3(-0.4,0.8,0.5)));
 vec3 soot=lit>0.5?vec3(0.44,0.34,0.28):(lit>-0.15?vec3(0.25,0.18,0.15):vec3(0.09,0.06,0.05));
  ALBEDO=mix(soot,hot*(lit> -0.25?1.0:0.67),heat);
 // Fuel supply ends at the neck; its soft trailing boundary advects upward.
 // This is continuous optical density, never a noise/discard mask.
 float smoke = smoothstep(1.15,1.65,phase);
 float supply_front = clamp((phase-1.7)/1.45,0.0,1.15);
 float supplied = smoothstep(supply_front-0.16,supply_front+0.22,UV.y);
 float top_air = 1.0-smoothstep(0.68,1.0,UV.y);
 float density = 1.0-smoothstep(1.7,3.15,phase);
 ALPHA=mix(1.0,supplied*top_air*density*0.28,smoke);
}



