shader_type spatial;
// 超能力：透視の窓（vfx/esper/esper_sight.gd）。壁の上に開く、目の形の窓。ふちの線と、中のうすい色、外へ広がる波紋。
// 板（1m 四方の Quad）を壁のすぐ手前に置いて使う。UV の中心が窓の中心。size＝板の一辺（m）。
//   radius  窓の半径（m） ／ squash  縦のつぶれ（1＝円、0＝閉じた目。まぶたのように開け閉めする）
//   line    閉じたあとに残る横の線：左右の端へ抜けていく量（0＝無し、0〜1＝まん中から端へ消える）
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 color = vec3(1.0, 0.45, 0.75);
uniform vec3 color_core = vec3(1.3, 1.2, 1.3);
uniform float size = 4.0;
uniform float radius = 1.0;
uniform float squash = 1.0;
uniform float phase = 0.0;
uniform float boil = 0.0;
uniform vec3 rings = vec3(2.0);         // 波紋3本の進み具合（0〜1）
uniform float line = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * size;
	p.y = -p.y;
	float around = atan(p.y, p.x) / 6.28318;
	float wob = (texture(noise_tex, vec2(around * 3.0, boil)).r - 0.5) * 0.12;
	vec2 q = vec2(p.x, p.y / max(squash, 0.02));
	float d = length(q) - radius * (1.0 + wob);
	float a = 0.0;
	vec3 col = color;
	// 中：うすい色。外から内へ、細い波が寄る（見通している感じ）
	if (d < 0.0) {
		float ripple = step(0.82, fract(length(q) * 3.2 + phase));
		a = 0.1 + 0.1 * ripple;
	}
	// ふち：太さの不揃いな線
	float edge = 0.035 * (0.6 + 0.9 * texture(noise_tex, vec2(around * 5.0 + 0.3, boil * 1.4)).r);
	if (abs(d) < edge * max(squash, 0.25)) {
		a = 0.95;
		col = mix(color, color_core, 0.5);
	}
	// 波紋：ふちと同じ形で外へ進み、細って切れる
	float torn = texture(noise_tex, vec2(around * 5.0 + 0.7, 0.21)).r;
	for (int i = 0; i < 3; i++) {
		float f = rings[i];
		if (f >= 0.0 && f < 1.0 && d > 0.0) {
			float r = 0.9 * (1.0 - (1.0 - f) * (1.0 - f));
			if (abs(d - r) < 0.02 * (1.0 - f) && torn > 0.36 + f * 0.5) {
				a = 0.9;
				col = mix(color, color_core, 0.4);
			}
		}
	}
	// 閉じたあとの横の線：まん中から左右の端へ抜ける
	if (squash < 0.03) {
		float along = abs(p.x) / max(radius, 0.01);
		a = (abs(p.y) < 0.02 && along < 1.0 && along > line) ? 0.95 : 0.0;
		col = mix(color, color_core, 0.5);
	}
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a;
}
