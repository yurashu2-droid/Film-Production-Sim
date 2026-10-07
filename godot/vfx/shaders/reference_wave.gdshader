shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float radius=2.0;
uniform float width=0.33;
uniform float phase=0.0;
uniform float fade=1.0;
varying float radial;
varying float across;
void vertex(){
 float r=length(VERTEX.xz);
 vec2 d=VERTEX.xz/max(r,0.001);
 radial=(r-1.0)/0.15;
 across=VERTEX.y/0.15;
 float a=atan(d.y,d.x);
 VERTEX.xz=d*(radius+radial*width)*(1.0+0.012*sin(a*5.0-phase*2.0));
 VERTEX.y=across*width*0.5+0.04*sin(a*3.0-phase*1.7);
}
void fragment(){
 float facing=smoothstep(-0.3,0.85,radial);
 ALBEDO=mix(vec3(2.6,0.12,0.01),vec3(4.0,0.55,0.025),facing);
 ALPHA=fade*0.8;
}
