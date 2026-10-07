shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,skip_vertex_transform;
uniform float width=0.3;
uniform float heat=1.0;
uniform bool shock=false;
void vertex(){
 vec3 p=(MODELVIEW_MATRIX*vec4(VERTEX,1)).xyz;
 vec3 t=(MODELVIEW_MATRIX*vec4(NORMAL,0)).xyz;
 vec3 s=cross(t,normalize(p));
 s=dot(s,s)>0.00001?normalize(s):vec3(1,0,0);
 float form=shock?1.0:pow(1.0-UV.x,0.55)*(0.3+0.7*sin(UV.x*3.14159));
 VERTEX=p+s*(UV.y-0.5)*width*form;
 NORMAL=vec3(0,0,1);
}
void fragment(){
 float edge=abs(UV.y-0.5)*2.0;
 vec3 hot=edge<0.3?vec3(8,6,1.1):(edge<0.66?vec3(5,2.3,0.06):vec3(3,0.35,0.025));
 ALBEDO=mix(vec3(0.8,0.06,0.01),hot,heat);
}
