shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform float width = 0.3;
uniform float heat = 1.0;
uniform float thin = 1.0;
void vertex(){
 vec3 p = (MODELVIEW_MATRIX*vec4(VERTEX,1)).xyz;
 vec3 tangent = (MODELVIEW_MATRIX*vec4(NORMAL,0)).xyz;
 vec3 side = cross(tangent,normalize(p));
 side = dot(side,side)>0.00001 ? normalize(side) : vec3(1,0,0);
 float shape = sqrt(max(0.0,1.0-UV.x))* (0.3+0.7*sin(UV.x*3.14159));
 VERTEX = p+side*(UV.y-0.5)*width*shape*thin;
 NORMAL = vec3(0,0,1);
}
void fragment(){
 float edge = abs(UV.y-0.5)*2.0;
 vec3 white = edge < 0.3 ? vec3(9,7,2) : vec3(5,2.3,0.08);
 vec3 red = edge < 0.3 ? vec3(3.3,0.55,0.06) : vec3(1.2,0.1,0.02);
 ALBEDO = mix(red,white,heat);
}
