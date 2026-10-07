shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled,skip_vertex_transform;
uniform float width=0.2;
uniform vec3 color=vec3(7.0,2.0,0.1);
uniform float phase=0.0;
void vertex(){vec3 p=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;vec3 t=(MODELVIEW_MATRIX*vec4(NORMAL,0.0)).xyz;vec3 s=cross(t,normalize(p));s=dot(s,s)>0.000001?normalize(s):vec3(1.0,0.0,0.0);float shape=pow(max(0.0,sin(UV.x*3.14159)),0.7)*(0.8+0.2*sin(UV.x*9.0-phase*4.0));VERTEX=p+s*(UV.y-0.5)*width*shape;NORMAL=vec3(0.0,0.0,1.0);}
void fragment(){float c=abs(UV.y-0.5)*2.0;ALBEDO=mix(color,color*1.5,smoothstep(0.5,0.1,c));ALPHA=smoothstep(1.0,0.6,c);}
