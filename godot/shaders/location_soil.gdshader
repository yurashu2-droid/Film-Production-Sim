shader_type spatial;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 f = fract(point);
	vec2 t = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), t.x),
			mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), t.x), t.y);
}

void fragment() {
	float large = noise(world_xz * 0.38);
	float gravel = noise(world_xz * 10.0);
	float verge = smoothstep(11.0, 16.8, abs(world_xz.y))
			+ smoothstep(13.5, 20.0, abs(world_xz.x));
	float weeds = smoothstep(0.62, 0.88, large + 0.37 * verge);
	vec3 clay = mix(vec3(0.29, 0.217, 0.135), vec3(0.40, 0.325, 0.224), large);
	ALBEDO = mix(clay, vec3(0.24, 0.278, 0.136), weeds * 0.75) * (0.83 + 0.32 * gravel);
	ROUGHNESS = 1.0;
}
