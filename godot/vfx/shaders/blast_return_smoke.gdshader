shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
uniform float phase=0.0;
varying vec3 wn;
void vertex(){
 float h=VERTEX.y+0.6;
 VERTEX.x+=0.15*sin(h*3.0+phase*2.0)*h;
 VERTEX.z+=0.11*cos(h*4.0-phase*1.8)*h;
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float lit=dot(wn,normalize(vec3(-0.4,0.8,0.5)));
 ALBEDO=COLOR.rgb*(lit>0.5?1.3:(lit>-0.1?1.0:0.62));
 ALPHA=COLOR.a;
}
