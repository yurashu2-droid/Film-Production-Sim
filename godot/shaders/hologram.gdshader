// 青いホログラム（情報商材の投影機が映す影。features/delivery_box.gd の講師と、features/holo_guides.gd のガイド）
// 縁ほど明るく（フレネル）、横じまが上へ流れ、ときどきちらつく。光の影響は受けない
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.30, 0.70, 1.0, 1.0);
uniform float strength = 1.0;      // 全体の濃さ（出てくる・消えるときに 0 ↔ 1）
uniform float base_alpha = 0.22;   // 正面から見たときの濃さ
uniform float flicker = 0.35;      // ちらつきの強さ

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	float scan = 0.6 + 0.4 * step(0.5, fract(world_pos.y * 16.0 - TIME * 1.2));
	float blink = 1.0 - flicker * step(0.93, fract(sin(floor(TIME * 12.0)) * 43758.5453));
	ALBEDO = mix(tint.rgb, vec3(1.0), rim * 0.45);
	ALPHA = clamp((base_alpha + 0.75 * rim) * scan * blink * strength, 0.0, 1.0);
}
