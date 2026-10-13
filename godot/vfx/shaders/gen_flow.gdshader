shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform sampler2D field_map : filter_linear, repeat_enable;
uniform float phase;
uniform float travel;
uniform float layer;
uniform float seed;
void fragment() {
	vec2 p = vec2(UV.x+UV.y*0.31+phase*(0.07+layer*0.023)+seed, UV.y*0.73-travel*0.27-phase*0.11);
	vec4 f = texture(field_map,p);
	vec4 second = texture(field_map,p*vec2(0.67,0.83)+vec2(layer*0.271,seed+phase*0.041));
	// Persistent separated streams; thresholds never change with effect lifetime.
	float coverage = smoothstep(0.10+layer*0.015,0.32,f.b*0.58+second.b*0.42);
	float edge = smoothstep(0.0,0.08,UV.y)*(1.0-smoothstep(0.86,1.0,UV.y));
	ALPHA = coverage*edge*(0.36+layer*0.10);
	vec3 outer = vec3(0.35,0.23,0.08);
	vec3 middle = vec3(1.0,0.72,0.23);
	vec3 core = vec3(1.35,1.24,0.91);
	ALBEDO = layer < 0.5 ? outer : (layer < 1.5 ? middle : core);
	ROUGHNESS = 0.24;
	SPECULAR = 0.75;
	EMISSION = ALBEDO*(0.08+layer*0.09);
}
