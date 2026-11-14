shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
uniform float phase=0.0;
uniform float arrival=3.5;
uniform float seed=0.0;
uniform sampler2D grain:filter_linear_mipmap,repeat_enable;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float g=texture(grain,p*1.1+seed).r;
 float rim=1.0-smoothstep(0.57+g*0.22,0.78+g*0.20,length(p));
 float spread=smoothstep(arrival,arrival+0.24,phase);
 float wick=clamp((phase-(4.42+sin(seed)*0.11))/0.67,0.0,1.3);
 float dry=smoothstep(wick*2.4-1.25,wick*2.4-0.90,p.x+0.08*sin(p.y*8.0));
 ALBEDO=mix(vec3(0.012,0.009,0.015),vec3(0.18,0.14,0.12),smoothstep(4.30,4.90,phase));
 ALPHA=rim*spread*dry*0.75;
}
