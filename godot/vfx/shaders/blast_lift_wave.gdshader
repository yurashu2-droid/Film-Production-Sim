shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform float thickness=1.0;
uniform float phase=0.0;
void vertex(){float a=atan(VERTEX.z,VERTEX.x);vec2 axis=normalize(VERTEX.xz);VERTEX.xz=axis*(1.0+(length(VERTEX.xz)-1.0)*thickness);VERTEX.y*=thickness;VERTEX.y+=sin(a*5.0+phase*3.0)*0.028*thickness;}
void fragment(){ALBEDO=mix(vec3(4.0,0.65,0.04),vec3(6.5,2.4,0.18),pow(abs(sin(UV.y*6.28318)),5.0));}
