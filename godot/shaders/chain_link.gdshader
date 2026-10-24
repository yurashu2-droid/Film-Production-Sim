shader_type spatial;
// 金網（ひし形の菱目、または縦長の溶接金網）。網目は UV（メートル）から計算して抜く。
// 遠くで網目が画面の数ピクセルより細かくなっても、針金を1ピクセルより細くしない。
// 網目がつぶれるほど遠いと、面が針金の色で埋まる（テクスチャのミップマップで網が透けて消える問題をなくす）。
render_mode cull_disabled;

uniform vec2 pitch = vec2(0.055, 0.055);   // 網目の間隔（メートル）。x：横、y：縦
uniform float wire = 0.005;                // 針金の太さ（メートル）
uniform bool diamond = true;               // true：ひし形（金網フェンス）、false：格子（溶接金網）
uniform float min_px = 1.15;               // 針金の、画面での最小の太さ（ピクセル）
uniform float roughness_v = 0.55;
uniform float metallic_v = 0.35;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 q = UV / pitch;
	if (diamond) {
		q = vec2(q.x + q.y, q.x - q.y) * 0.5;
	}
	vec2 dist = 0.5 - abs(fract(q) - 0.5);          // 一番近い針金までの距離（網目の幅を1とする）
	vec2 px = fwidth(q);
	vec2 half_w = max(vec2(wire) / pitch * 0.5, px * min_px * 0.5);
	if (dist.x > half_w.x && dist.y > half_w.y) {
		discard;
	}
	// 針金の丸み：線の中心ほど明るく、縁を少し暗く（近くで見たときの立体感）
	float edge = min(dist.x / max(half_w.x, 1e-4), dist.y / max(half_w.y, 1e-4));
	float shade = mix(0.82, 1.0, 1.0 - clamp(edge, 0.0, 1.0));
	ALBEDO = to_linear(COLOR.rgb) * shade;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
}
