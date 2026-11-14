shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float phase = 0.0;
uniform int mode = 0;

void fragment() {
	vec2 p = (floor(UV * vec2(42.0, 12.0)) + 0.5) / vec2(42.0, 12.0);
	float shoulder = 0.78 + 0.17 * sin(p.x * 29.0 + sin(p.x * 13.0) * 1.4);
	float edge = abs(p.y - 0.5) * 2.0;
	if (edge > shoulder) { discard; }
	float core = 1.0 - smoothstep(0.10, 0.65, edge);
	float value = floor((0.42 + core * 0.43) * 5.0) / 5.0;
	ALBEDO = COLOR.rgb * value;
	EMISSION = COLOR.rgb * (0.26 + core * 0.66);
	ALPHA = COLOR.a * (0.65 + core * 0.35);
	if (mode == 1) {
		float fold = 0.52 + 0.23 * sin(p.x * 18.0 - p.y * 6.0 - phase * 0.9);
		ALBEDO = COLOR.rgb * (0.32 + fold * 0.38);
		EMISSION = COLOR.rgb * (0.16 + fold * 0.36);
		ALPHA = COLOR.a * (0.14 + fold * 0.23) * (1.0 - edge * 0.65);
	}
}
