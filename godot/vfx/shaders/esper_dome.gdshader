shader_type spatial;
// 超能力：念の壁（ドーム）。ふだんは、ふちと床との継ぎ目がうっすら見えるだけ。物が当たった所から、六角の波紋が走る（vfx/esper/esper_barrier.gd）。
// 半球のメッシュ（中心が原点、半径1）に貼る。両面を描くので、手前と奥の六角が重なって奥行きが出る。
//   hits   当たった向き（xyz。中心からの単位ベクトル）と、当たってからの秒（w。負＝無し）を6つまで
//   strain 全体の六角が浮かび上がる量（強く押されている時）
//   tear   最後に外へ広がる時、千切れていく量（0〜1）
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 hits[6];
uniform float hit_speed = 2.8;          // 波紋が走る速さ（ラジアン/秒）
uniform float hit_life = 0.85;
uniform vec3 color = vec3(0.3, 0.9, 0.55);
uniform vec3 color_core = vec3(1.2, 1.35, 1.25);
uniform float cells = 8.0;              // 六角の細かさ
uniform float rim = 0.2;
uniform float strain = 0.0;
uniform float tear = 0.0;
uniform float warp = 1.0;

varying vec3 dir;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(dir);
	// てっぺんから見た平面へ広げてから、六角に区切る（てっぺんでも目が詰まらない）
	vec2 p = d.xz / (1.0 + max(d.y, 0.0)) * cells;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 hh = r * 0.5;
	vec2 a = mod(p, r) - hh;
	vec2 b = mod(p - hh, r) - hh;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	float edge = 0.5 - max(abs(gv.x), dot(abs(gv), normalize(r)));
	float cell = hash(floor((p - gv) * 2.0 + 0.5));
	float line = smoothstep(0.07 * (1.0 - 0.6 * tear), 0.025 * (1.0 - 0.6 * tear), edge);
	// 当たった所から走る波紋：先頭が通る六角は強く光り、通ったあとは少し残る
	float glow = 0.0;
	float push = 0.0;
	for (int i = 0; i < 6; i++) {
		float t = hits[i].w;
		if (t >= 0.0 && t < hit_life) {
			float k = t / hit_life;
			float ang = acos(clamp(dot(d, hits[i].xyz), -1.0, 1.0));
			float front = t * hit_speed + 0.12;
			// 六角ごとに少しずつ遅らせる（なめらかな輪ではなく、六角の板が順に光る）
			float lag = (cell - 0.5) * 0.22;
			float lead = smoothstep(0.34, 0.0, abs(ang + lag - front));
			float left = step(ang + lag, front) * (1.0 - k) * 0.3;
			glow = max(glow, (lead + left) * (1.0 - k * k));
			push += lead * (1.0 - k) * sign(ang - front);
		}
	}
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float base = rim * (pow(1.0 - facing, 2.2) * 0.9 + smoothstep(0.1, 0.0, d.y) * 0.9);
	float show = clamp(glow + strain, 0.0, 1.0);
	float alpha = max(base, max(line * show, show * 0.26 * (0.3 + 0.7 * cell)));
	// 最後：外へ広がりながら、六角の板ごとに千切れて消える
	if (cell * 0.8 + texture(noise_tex, p * 0.06).r * 0.4 < tear * 1.25 - 0.05) {
		discard;
	}
	vec3 col = mix(color, color_core, clamp(line * show + pow(1.0 - facing, 3.0) * 0.5, 0.0, 1.0));
	vec2 off = normalize(gv + vec2(0.0001)) * push * 0.012 * warp;
	vec3 behind = texture(screen_tex, SCREEN_UV + off).rgb;
	ALBEDO = mix(behind, col, alpha);
	ALPHA = clamp(max(alpha, abs(push) * 0.9), 0.0, 1.0);
}
