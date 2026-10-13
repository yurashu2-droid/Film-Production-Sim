shader_type spatial;
// punk3d の輪郭線（next_pass に付ける）。裏面を画面上で外へ押し出して、墨の線にする。
// 線の太さは場所ごとに違い、8 コマ/秒で変わる（手描きの線の震え）。画面上の太さなので、物の拡大縮小で変わらない。
render_mode unshaded, cull_front, shadows_disabled;

uniform vec3 ink = vec3(0.03, 0.03, 0.035);
uniform float width = 0.017;           // 画面の高さに対する線の太さ
uniform float tone_scale = 64.0;
uniform float wear = 0.0;
uniform float phase = 0.0;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = MODELVIEW_NORMAL_MATRIX * NORMAL;
	vec2 dir = normalize(n.xy + vec2(0.0001, 0.0));
	float boil = floor(phase * 8.0);
	float weight = 0.55 + 0.9 * h3(floor(VERTEX * 6.0) + boil);
	clip.xy += dir * width * weight * clip.w * vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0);
	POSITION = clip;
}

void fragment() {
	vec2 sp = FRAGCOORD.xy / VIEWPORT_SIZE.y * tone_scale;
	sp = vec2(sp.x + sp.y, sp.x - sp.y) * 0.7071;
	if (length(fract(sp) - 0.5) > 0.72 * (1.0 - wear)) {
		discard;
	}
	ALBEDO = ink;
}
