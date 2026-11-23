// スロー光線：宙に浮いて、ゆっくり漂う小さな光のかけら（光線の中のほこり）。カメラを向く小さな板。
// INSTANCE_CUSTOM.x＝明るさ（0〜1）、.y＝縦への伸び（0〜1。消えていく時に、上へ細く伸びる）
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec3 light = vec3(0.95, 0.92, 1.0);
uniform vec3 ink = vec3(0.24, 0.17, 0.4);

varying float glow;

void vertex() {
	glow = INSTANCE_CUSTOM.x;
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 centre = VIEW_MATRIX * vec4((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz, 1.0);
	centre.xy += VERTEX.xy * s * vec2(1.0 - 0.45 * INSTANCE_CUSTOM.y, 1.0 + 1.6 * INSTANCE_CUSTOM.y);
	POSITION = PROJECTION_MATRIX * centre;
}

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	// 4つの角が細く伸びた、小さなきらめきの形
	float star = p.x * p.y * 16.0 + (p.x + p.y) * 0.4;
	float body = 1.0 - smoothstep(0.34, 0.42, star);
	float edge = 1.0 - smoothstep(0.56, 0.68, star);
	ALBEDO = mix(ink, light, body);
	ALPHA = max(body, edge * 0.85) * glow;
}
