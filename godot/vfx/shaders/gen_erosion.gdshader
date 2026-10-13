shader_type spatial;
render_mode cull_disabled;
uniform sampler2D fracture_image : source_color, filter_linear, repeat_enable;
uniform vec2 seed_uv;
uniform float curl;
uniform float flatten;
uniform float reveal;
uniform float peel;
uniform float dry;
void vertex() {
	// Each region bends about its attachment. Distal vertices curl first.
	float d = VERTEX.y+0.36;
	float a = curl*d*4.8;
	float original_y = VERTEX.y;
	VERTEX.y = mix(original_y, sin(a)/4.8-0.36,curl);
	VERTEX.z += curl*(1.0-cos(a))/4.8;
	VERTEX.x += curl*0.10*sin(d*4.0+seed_uv.x*9.0);
	VERTEX.z *= 1.0-flatten*0.94;
}
void fragment() {
	float growth = (1.0-UV.y)+0.09*sin(UV.x*6.283+1.1)+0.05*cos(UV.x*18.849);
	if (growth > reveal*1.16-0.03) { discard; }
	vec3 src = texture(fracture_image,UV).rgb;
	float tone = dot(src,vec3(0.2126,0.7152,0.0722));
	vec3 red = mix(vec3(0.24,0.015,0.006),vec3(0.78,0.075,0.024),0.36+tone*0.64);
	vec3 underside = vec3(0.91,0.41,0.12);
	ALBEDO = FRONT_FACING ? underside : red;
	ALBEDO = mix(ALBEDO,vec3(0.17,0.034,0.012),dry*0.76);
	ROUGHNESS = 0.28+dry*0.6;
	METALLIC = 0.12*(1.0-dry);
	EMISSION = FRONT_FACING ? underside*0.12*(1.0-flatten) : vec3(0.0);
}

