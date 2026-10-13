shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
uniform float phase=0.0;
uniform float layer=0.0;
uniform float seed=0.0;
uniform sampler2D grain:filter_linear_mipmap,repeat_enable;
varying float height;
void vertex(){height=VERTEX.y;}
void fragment(){
 float u=UV.x;float v=UV.y;
 float g=texture(grain,vec2(u*2.2+v*.7+seed,v*.65-phase*.31+seed)).r;
 float fine=texture(grain,vec2(u*7.0-v*2.0+seed,v*1.2-phase*.5)).r;
 float porous=smoothstep(.57,.65,g+fine*.12);
 float edge=smoothstep(.0,.07,v)*(1.0-smoothstep(.92,1.0,v));
 float opacity=.78;
 vec3 color=vec3(.010,.008,.014);
 float exiting=1.0;
 if(layer>.5&&layer<1.5){color=vec3(.033,.021,.014);opacity=.65;porous*=smoothstep(.48,.59,g);}
 else if(layer>1.5&&layer<2.5){
  color=mix(vec3(.65,.29,.04),vec3(1.7,.95,.20),g);opacity=.82;
  porous*=pow(max(0.0,sin(u*13.0+v*4.0-phase*2.1+seed*8.0)),7.0);
  float supply=(phase-1.80)/.78;
  exiting=smoothstep(supply-.10,supply+.10,v);
 } else if(layer>2.5){
  color=vec3(3.2,2.8,2.2);opacity=.7;
  porous*=exp(-pow((v-.70)/.20,2.0));
  exiting=smoothstep(.35,.55,phase-seed*.5)*(1.0-smoothstep(1.20,1.60,phase-seed*.5));
 }
 ALBEDO=color;
 ALPHA=porous*edge*opacity*exiting*smoothstep(.025,.12,height);
}
