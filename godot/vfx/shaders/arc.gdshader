shader_type spatial;
// 稲妻。折れ線の形を作らず、板の上で「流れるノイズで位置をずらした線」を描く（ゼルダBotWなどの作り方）。
// 線は有機的にくねり、途中から枝が分かれ、ノイズが流れるのに合わせて連続して形を変える。
// 断面は内から：芯（背景を隠す色。黒にできる）→ ふち（強い色）→ にじみ（まわりへ足す光）。
// 乗算済みアルファで描くので、黒い芯は背景を隠し、にじみは足し算になる。
//   帯（vfx_ribbon.gd の2点の帯）に使う。UV.x は根元0〜先端1、UV.y は幅方向。
//   web = true にすると、カメラ向きの板の上に、放射状に這う放電の網を描く（ノイズがある値をまたぐ所だけを線にする）。
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform sampler2D noise_texture : filter_linear, repeat_enable;
uniform bool web = false;
uniform float width = 2.0;            // 板の幅（線がくねる範囲）
uniform float phase = 0.0;
uniform float seed = 0.0;             // 変えると別の形になる（光り直し）
uniform float variation = 0.55;       // くねりの大きさ（板の半幅に対する割合）
uniform float frequency = 1.1;        // くねりの細かさ
uniform float speed = 1.2;            // ノイズが先端へ流れる速さ
uniform float morph = 0.9;            // 形そのものが変わっていく速さ
uniform float thickness = 0.07;       // 線の太さ（板の半幅に対する割合）
uniform float forks = 2.0;            // 枝の数（0〜3）
uniform vec3 core_color = vec3(0.0);
uniform vec3 rim_color = vec3(9.0, 0.5, 0.3);
uniform float glow = 0.5;
uniform float core_part = 0.7;        // 線の太さのうち、芯が占める割合（残りがふち）
uniform float reveal = 1.0;           // 根元からここまで描く
uniform float fade = 1.0;

void vertex() {
	if (web) {
		// カメラ向きの板
		vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		VERTEX = centre + vec3(VERTEX.xy * width, 0.0);
	} else {
		vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 t = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		vec3 view = PROJECTION_MATRIX[3][3] == 0.0 ? normalize(p) : vec3(0.0, 0.0, -1.0);
		vec3 side = cross(t, view);
		side = dot(side, side) > 0.000001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
		VERTEX = p + side * (UV.y - 0.5) * width;
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
}

// 大きなうねりに細かい震えを重ねた、−0.75〜0.75 くらいの揺れ
float wave(float x, float s) {
	float a = texture(noise_texture, vec2(x * frequency - phase * speed + s, phase * morph * 0.31 + s * 1.7)).r;
	float b = texture(noise_texture, vec2(x * frequency * 3.3 - phase * speed * 1.9 + s * 2.3, phase * morph * 0.53 + s)).r;
	return (a - 0.5) + (b - 0.5) * 0.3;
}

void fragment() {
	float v = 1000.0;      // 線の中心からの距離（1 でふちの外端）
	float along = 0.0;
	if (web) {
		vec2 p = UV - 0.5;
		float r = length(p) * 2.0;
		float n = texture(noise_texture, p * frequency + vec2(seed, phase * morph * 0.4)).r;
		float m = texture(noise_texture, p * frequency * 2.3 - vec2(phase * morph * 0.3, seed)).r;
		// ノイズが 0.5 をまたぐ所だけが線になる。もう一枚のノイズで、線の出る場所をまだらにする
		float line = abs(n - 0.5 + (m - 0.5) * 0.3);
		float patch = smoothstep(0.56, 0.7, texture(noise_texture, p * frequency * 0.6 + vec2(phase * morph * 0.25, seed * 2.0)).r);
		float ring = smoothstep(0.08, 0.2, r) * smoothstep(1.0, 0.55, r);
		v = line / max(thickness * 0.5, 0.0005) / max(patch * ring, 0.001);
		along = r;
	} else {
		float x = UV.x;
		float y = (UV.y - 0.5) * 2.0;
		float pin = smoothstep(0.0, 0.2, x);              // 根元は動かさない
		float centre = wave(x, seed) * variation * 2.0 * pin;
		float thin = mix(1.0, 0.18, pow(x, 1.4));           // 先へ細る
		v = abs(y - centre) / max(thickness * thin, 0.0005);
		// 枝：途中から本流を離れていく。本流より細い
		for (int k = 1; k <= 3; k++) {
			if (float(k) > forks) {
				break;
			}
			float start = 0.16 + 0.2 * float(k) + 0.08 * sin(seed * 3.0 + float(k) * 2.1);
			float away = smoothstep(start, start + 0.35, x);
			float side = (mod(float(k) + floor(seed), 2.0) < 1.0) ? 1.0 : -1.0;
			float branch = centre + (wave(x * 1.4, seed + float(k) * 5.3) * 1.3 + side * 0.55) * variation * 1.6 * away;
			float end = smoothstep(start + 0.62, start + 0.3, x);      // 枝は本流より先に尽きる
			float vb = abs(y - branch) / max(thickness * thin * 0.55 * end, 0.0005);
			v = (x > start) ? min(v, vb) : v;
		}
		// 先端はノイズでちぎれて終わる。板のふちでは消す
		float tip = reveal - x - (texture(noise_texture, vec2(y * 0.5 + seed, phase * 0.7)).r - 0.5) * 0.1;
		v = (tip < 0.0 || abs(y) > 0.97) ? 1000.0 : v;
		along = x;
	}
	if (v > 3.4) {
		discard;
	}
	// 断面：芯 → ふち → にじみ
	float halo = pow(max(1.0 - (v - 1.0) / 2.4, 0.0), 2.0);
	vec3 col = rim_color * glow * halo;
	float cover = 0.0;
	if (v < 1.0) {
		col = rim_color;
		cover = 1.0;
	}
	if (v < core_part) {
		col = core_color;
	}
	ALBEDO = col * fade * (1.0 - 0.3 * along);
	ALPHA = cover * fade;
}
