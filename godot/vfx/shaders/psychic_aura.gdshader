shader_type spatial;
// 念力のオーラ：つかんだ物（や手）の輪郭に沿って出る「念の膜」（vfx_psychic.gd）。
// カメラへ向けた板を物の後ろに置き、物の外形の点（pts）を画面に写して、その外形からの距離 d をここで求める。
// 物そのものには重ならない（板は物の後ろ）。どのカメラから見ても、そのカメラから見た輪郭に沿う。
// 奥行きの判定は、場所で使い分ける（front）：輪郭の外にはみ出す部分は「物の手前側の奥行き」で比べるので、
// 物が壁や床にくっついていても隠れない。輪郭の内側（物の形のすき間を埋める所）は「物の後ろ」のままなので、物を隠さない。
//   膜    … 輪郭の外へ少しはみ出す色の面。外側のふちが jag=1 でギザギザに、0 でゆらゆらに沸く（frame・boil で描き替える）。
//            いちばん外のふちより内側は、全部塗る（穴を開けない）。物は板の手前にあるので、物そのものは隠れない
//   波紋  … 輪郭と同じ形の線が外へ進み、進むほど細り、途中で弧に切れて消える（rings に 0〜1 の進み具合を3本ぶん）
//   ゆがみ… 帯と波紋のまわりで、後ろの景色をずらす
//   色ずれ… 帯を左右に少しずらした2色（split）。超能力らしい色のにじみ
//   reveal / drain … つかんだ点から外へ包む／つかんだ点の側から抜ける
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform mat4 body = mat4(1.0);          // pts を置く変換（物のワールド変換。手なら単位行列）
uniform vec3 pts[16];
uniform int pt_count = 1;
uniform vec3 center = vec3(0.0);        // 物の中心（ワールド）
uniform float extent = 1.0;             // 板の半分の大きさ（m）
uniform float back = 0.3;               // 板を物の後ろへ下げる距離（m）
uniform float pad = 0.0;                // 外形をこの長さだけ丸く膨らませる（手のまわりなど）
uniform float front = 0.0;              // 0 より大きいと、輪郭の外の部分を、物の中心よりこの距離だけ手前の奥行きで比べる（壁・床に隠れない）
uniform float lip = 0.0;                // 輪郭からこの距離までは、物の後ろのままにする（丸い物の、外形の点からはみ出す縁を塗らない）

uniform float band = 0.02;              // 帯の、いつもある太さ（m）
uniform float amp = 0.06;               // 帯の、沸いて伸びる長さ（m）
uniform float jag = 1.0;                // 1＝ギザギザ ／ 0＝ゆらゆら
uniform float teeth = 9.0;              // ギザギザの数（1m あたり）
uniform float sharp = 1.2;
uniform float rise = 0.5;               // 上側を長くする割合（炎のように立つ）
uniform float frame = 0.0;              // コマ番号（ギザギザを描き替える）
uniform float boil = 0.0;               // ゆらゆらの進み
uniform vec3 trail_world = vec3(0.0);   // 物の動きの向き × 強さ（ワールド。動く向きの後ろ側が伸びる）
uniform float split = 0.0;              // 色ずれの幅（m）
uniform vec3 color = vec3(0.5, 0.3, 1.0);
uniform vec3 color_core = vec3(1.3, 1.25, 1.45);
uniform vec3 color_a = vec3(1.0, 0.35, 0.8);
uniform vec3 color_b = vec3(0.3, 0.85, 1.0);
uniform float opacity = 0.9;
uniform float haze = 0.0;               // 帯の外の、やわらかいもやの濃さ
uniform float haze_reach = 0.25;

uniform vec3 rings = vec3(2.0);         // 波紋3本の進み具合（0〜1。1以上は出さない）
uniform float ring_reach = 0.4;         // 波紋が進む距離（m）
uniform float ring_width = 0.012;
uniform float ring_gain = 1.0;
uniform float warp = 0.0;               // ゆがみの強さ

uniform vec3 grip = vec3(0.0);          // つかんだ点（ワールド）
uniform float reveal = 100.0;           // つかんだ点からこの距離まで見せる
uniform float drain = -1.0;             // つかんだ点からこの距離まで消す

varying vec2 q;
varying vec2 grip_q;
varying float away;
varying vec2 trail;
varying vec4 h0;
varying vec4 h1;
varying vec4 h2;
varying vec4 h3;
varying vec4 h4;
varying vec4 h5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 turn(int k) {
	float a = float(k) * 0.2617994;
	return vec2(cos(a), sin(a));
}

void vertex() {
	vec3 c = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	float cz = min(c.z, -0.05);
	mat4 to_view = VIEW_MATRIX * body;
	float h[24];
	for (int k = 0; k < 24; k++) {
		h[k] = -1000.0;
	}
	// 外形の点を、物の中心の奥行きの面へ写す。24 方向それぞれで、いちばん外の点までの長さを覚える
	for (int i = 0; i < pt_count; i++) {
		vec3 p = (to_view * vec4(pts[i], 1.0)).xyz;
		vec2 v = p.xy * (cz / min(p.z, -0.05)) - c.xy;
		for (int k = 0; k < 24; k++) {
			h[k] = max(h[k], dot(turn(k), v));
		}
	}
	h0 = vec4(h[0], h[1], h[2], h[3]);
	h1 = vec4(h[4], h[5], h[6], h[7]);
	h2 = vec4(h[8], h[9], h[10], h[11]);
	h3 = vec4(h[12], h[13], h[14], h[15]);
	h4 = vec4(h[16], h[17], h[18], h[19]);
	h5 = vec4(h[20], h[21], h[22], h[23]);
	vec3 g = (VIEW_MATRIX * vec4(grip, 1.0)).xyz;
	grip_q = g.xy * (cz / min(g.z, -0.05)) - c.xy;
	q = VERTEX.xy * 2.0 * extent;
	away = -cz;
	trail = (VIEW_MATRIX * vec4(trail_world, 0.0)).xy;
	// 物の後ろへ下げる（見かけの大きさと位置は保つ）
	VERTEX = vec3(c.xy + q, cz) * ((away + back) / away);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

// 外形からの距離（外が正）。n＝いちばん近い辺の外向き、side＝その辺の番号
float outline(vec2 p, float h[24], out vec2 n, out float side) {
	float best = -1000.0;
	n = vec2(0.0, 1.0);
	side = 0.0;
	for (int k = 0; k < 24; k++) {
		vec2 dir = turn(k);
		float v = dot(dir, p) - h[k];
		if (v > best) {
			best = v;
			n = dir;
			side = float(k);
		}
	}
	return best - pad;
}

// その場所での帯の太さ
float reach_of(vec2 p, vec2 n, float side, vec2 drag, float grow) {
	float along = dot(p, vec2(-n.y, n.x));
	float c = along * teeth / grow + side * 3.7;
	float cell = floor(c);
	// 歯ごとに違うコマで長さを替える（全部が同時に替わると、点滅に見える）
	float beat = floor(frame * (0.5 + 0.5 * hash(vec2(cell, side))) + hash(vec2(side, cell)) * 4.0);
	float tall = hash(vec2(cell + side * 13.0, beat));
	float tooth = pow(max(1.0 - abs(fract(c) * 2.0 - 1.0), 0.0), sharp) * (0.25 + 0.75 * tall * tall);
	float around = atan(p.y, p.x) / 6.28318;
	float wob = texture(noise_tex, vec2(around * 3.0, boil)).r * 0.75 + texture(noise_tex, vec2(around * 7.0 + 0.4, boil * 1.7)).r * 0.45;
	float shape = mix(wob, tooth, jag);
	float lift = 1.0 + rise * max(n.y, 0.0) + 1.8 * max(dot(n, -drag), 0.0);
	return (band + amp * shape * lift) * grow;
}

// 膜の中か（1＝中）。いちばん外のふちより内側は、輪郭の内側も含めて全部が中（穴を開けない）
float in_band(vec2 p, float h[24], vec2 drag, float grow, out float depth_k) {
	vec2 n;
	float side;
	float d = outline(p, h, n, side);
	float top = reach_of(p, n, side, drag, grow);
	depth_k = d / max(top, 0.0001);
	return step(d, top);
}

void fragment() {
	float h[24];
	h[0] = h0.x; h[1] = h0.y; h[2] = h0.z; h[3] = h0.w;
	h[4] = h1.x; h[5] = h1.y; h[6] = h1.z; h[7] = h1.w;
	h[8] = h2.x; h[9] = h2.y; h[10] = h2.z; h[11] = h2.w;
	h[12] = h3.x; h[13] = h3.y; h[14] = h3.z; h[15] = h3.w;
	h[16] = h4.x; h[17] = h4.y; h[18] = h4.z; h[19] = h4.w;
	h[20] = h5.x; h[21] = h5.y; h[22] = h5.z; h[23] = h5.w;
	vec2 n;
	float side;
	float d = outline(q, h, n, side);
	if (front > 0.0 && d > lip) {
		vec4 clip = PROJECTION_MATRIX * vec4(0.0, 0.0, -max(away - front, 0.06), 1.0);
		DEPTH = clip.z / clip.w;
	} else {
		DEPTH = FRAGCOORD.z;
	}
	float around = atan(q.y, q.x) / 6.28318;
	float grain = texture(noise_tex, q * 1.3 + vec2(0.3, boil * 0.3)).r;
	// つかんだ点から包む・抜ける（ふちは不揃いに）
	float from_grip = length(q - grip_q) + (grain - 0.5) * 0.16;
	float gate = step(from_grip, reveal) * step(drain, from_grip);

	float k_main;
	// 遠くの物ほど、帯も波紋も少し太く（画面の上で細くなりすぎない）
	float grow = clamp(away / 4.0, 0.85, 2.2);
	float main = in_band(q, h, trail, grow, k_main) * gate;
	vec3 col = mix(color_core, color, smoothstep(0.1, 0.32, k_main));
	// 輪郭の内側（物の形のすき間から見える所）は、芯の白より少し色を乗せる
	col = mix(col, mix(color_core, color, 0.55) * 0.92, smoothstep(0.0, 0.1, -d));
	float a = main * opacity;
	if (split > 0.0 && main < 0.5) {
		float k_side;
		float left = in_band(q + vec2(split, split * 0.4) * grow, h, trail, grow, k_side) * gate;
		float right = in_band(q - vec2(split, split * 0.4) * grow, h, trail, grow, k_side) * gate;
		if (left > 0.5) {
			col = color_a;
			a = opacity * 0.85;
		} else if (right > 0.5) {
			col = color_b;
			a = opacity * 0.85;
		}
	}
	// もや：帯の外に、やわらかく流れる
	if (haze > 0.0 && d > 0.0 && a < 0.01) {
		float flow = texture(noise_tex, q * 0.9 + vec2(boil * 0.25, -boil * 0.6)).r * 0.7 + grain * 0.5;
		// 届く距離だけを流れに合わせて変える（途中に穴を開けない）
		float soft = smoothstep(haze_reach * (0.55 + 0.9 * flow), 0.0, d);
		col = color;
		a = soft * haze * gate;
	}
	// 波紋：輪郭と同じ形の線が外へ進む。進むほど細り、途中で弧に切れる
	float wave = 0.0;
	float bend = 0.0;
	if (d > 0.0) {
		float wob = (texture(noise_tex, vec2(around * 2.0, boil * 0.4)).r - 0.5) * 0.06;
		float torn = texture(noise_tex, vec2(around * 5.0 + 0.7, 0.21)).r;
		for (int i = 0; i < 3; i++) {
			float f = rings[i];
			if (f >= 0.0 && f < 1.0) {
				float r = (band + ring_reach * (1.0 - (1.0 - f) * (1.0 - f))) * grow;
				float w = ring_width * grow * (1.0 - f) * (0.6 + 0.8 * torn);
				// 生まれた時から、ところどころ切れている（閉じた輪にしない）。進むほど切れ目が広がる
				float on = step(abs(d + wob - r), w) * step(0.36 + f * 0.5, torn);
				wave = max(wave, on);
				bend += (1.0 - f) * smoothstep(0.09, 0.0, abs(d + wob - r)) * sign(d + wob - r);
			}
		}
	}
	if (wave * ring_gain > a) {
		col = mix(color, color_core, 0.45);
		a = wave * ring_gain * opacity;
	}
	if (warp > 0.0) {
		// 後ろの景色をずらす：波紋の前後と、帯のすぐ外
		float near = smoothstep(0.3, 0.0, d) * step(-0.08, d);
		vec2 push = n * (bend * 0.02 + near * sin(d * 34.0 - boil * 9.0 + grain * 6.0) * 0.008) * warp;
		vec2 per_m = vec2(PROJECTION_MATRIX[0][0], -PROJECTION_MATRIX[1][1]) * 0.5 / away;
		vec3 behind = texture(screen_tex, SCREEN_UV + push * per_m).rgb;
		float lens = clamp(abs(bend) + near * 0.6, 0.0, 1.0) * gate;
		ALBEDO = mix(behind, col, a);
		ALPHA = max(a, lens);
	} else {
		ALBEDO = col;
		ALPHA = a;
	}
}
