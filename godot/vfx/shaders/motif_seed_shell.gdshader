shader_type spatial;
render_mode cull_disabled;
uniform float fade = 1.0;
void fragment() {
 float rib = pow(max(0.0, 1.0-abs(UV.y-0.5)*2.0), 18.0);
 float edge = smoothstep(0.04,0.19,UV.y)*smoothstep(0.04,0.19,1.0-UV.y);
 vec3 green = mix(vec3(0.14,0.22,0.025),vec3(0.44,0.61,0.07),edge);
 green += rib*vec3(0.24,0.25,0.065);
 green *= mix(0.65,1.1,sin(UV.x*3.14159));
 if (!FRONT_FACING) green=mix(green,vec3(0.63,0.68,0.16),0.52);
 ALBEDO=green;
 EMISSION=green*0.3;
 ROUGHNESS=0.49;
 ALPHA=fade;
}
