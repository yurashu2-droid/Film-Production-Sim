shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform float width = 0.3;
uniform float phase = 0.0;
uniform float cool = 0.0;
uniform float supply = 1.0;
uniform bool spark = false;
void vertex(){
 vec3 p=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec3 t=(MODELVIEW_MATRIX*vec4(NORMAL,0.0)).xyz;
 vec3 side=cross(t,normalize(p));
 side=dot(side,side)>0.00001 ? normalize(side) : vec3(1,0,0);
 float q=UV.x;
 float shape=spark ? pow(1.0-q,1.1)*(0.55+0.45*sin(q*3.14159)) : pow(sin(q*3.14159),0.65)*(0.7+0.3*sin(q*10.0-phase*13.0));
 VERTEX=p+side*(UV.y-0.5)*width*shape;
 NORMAL=vec3(0,0,1);
}
void fragment(){
 float edge=abs(UV.y-0.5)*2.0;
 float q=UV.x;
 float flow=sin(q*13.0+phase*16.0);
 vec3 head=mix(vec3(7.0,2.0,0.25),vec3(2.1,0.16,0.015),cool);
 vec3 tail=mix(vec3(2.5,0.25,0.02),vec3(0.5,0.035,0.008),cool);
 vec3 col=mix(head,tail,q);
 float broad=smoothstep(0.2,0.8,flow)*(1.0-edge)*0.25;
 // Broad orange folds; no narrow white core crossing the length of the ribbon.
 ALBEDO=col*(0.8+broad);
 float body=smoothstep(1.0,0.35,edge);
 ALPHA=(spark ? pow(1.0-q,0.65) : supply)*(1.0-cool*cool)*body;
}
