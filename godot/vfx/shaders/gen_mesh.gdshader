shader_type spatial;
render_mode cull_disabled;
uniform float clock = 0.0;
uniform float delay = 0.0;
uniform float variation = 0.0;
uniform bool broken = false;
uniform vec3 pivot = vec3(0.0);
varying float wave;
vec3 bend(vec3 p, float y, float opening) {
	float angle = opening * (1.15 + sin(variation * 1.9) * 0.12) * y;
	return vec3(p.x, p.y * cos(angle) - p.z * sin(angle), p.y * sin(angle) + p.z * cos(angle));
}
void vertex() {
	float t = clock - delay;
	float opening = smoothstep(0.65 + UV.y * 0.55, 1.6 + UV.y * 0.6, t);
	if (broken) opening = 1.0;
	float angle = opening * (1.15 + sin(variation * 1.9) * 0.12) * UV.y;
	VERTEX = bend(VERTEX, UV.y, opening);
	NORMAL.yz = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * NORMAL.yz;
	TANGENT.yz = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * TANGENT.yz;
	if (broken) VERTEX -= bend(pivot, pivot.y / 2.6, 1.0);
	wave = exp(-pow((UV.y - (t - 0.45) * 0.73) * 4.3, 2.0));
}
void fragment() {
	float t = clock - delay;
	float arrival = smoothstep(0.05, 1.0, t);
	float uneven_front = (sin(UV.x * 9.0 + variation * 1.7) * 0.11 + sin(UV.x * 22.0 + variation) * 0.05) * sin(arrival * 3.14159);
	if (!broken && UV.y > arrival + uneven_front) discard;
	float vein = pow(abs(sin(UV.x * 14.0 + UV.y * 7.3 + sin(UV.y * 9.0) * 1.3)), 28.0);
	float crack = vein * smoothstep(2.25, 2.80, t);
	vec3 tint = mix(vec3(0.35, 0.65, 0.75), vec3(0.82, 0.94, 1.0), UV.y * 0.6 + 0.22);
	ALBEDO = mix(tint, vec3(0.09, 0.24, 0.31), crack * 0.80);
	ROUGHNESS = 0.31 + crack * 0.3;
	METALLIC = 0.10;
	EMISSION = vec3(0.10, 0.27, 0.34) * wave * (broken ? 0.0 : 0.28);
}
