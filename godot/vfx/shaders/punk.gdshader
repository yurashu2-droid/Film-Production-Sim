shader_type spatial;
// パンクなペン画の絵柄で描く板（カメラ向き）。べた塗りの2色（塗り＋墨の線）だけ。光らせない。
//   mode 0  棘の破裂：長さの違う棘、かすれた輪郭、二重の下書き線、斜めハッチングの影
//   mode 1  ギザギザ：角ばった稲妻の帯。grow で描かれ、wear で描きはじめ側から走り去る
//   mode 2  ばんそうこうの×
//   mode 3  ちぎれた布の帯：弧を描く帯。下の縁が裂けて垂れる。grow で描かれ、wear で描きはじめ側から走り去る
//   mode 4  王冠の落書き：スプレーの線。grow の前半で左から描かれ、後半でペンキが垂れる。wear で掻き消される
//   mode 5  一本の棘：下から生える（grow）。wear で先から三段階に折れてなくなる
// 線は 8 コマ/秒で描き直す（位置が少し震え、かすれ方が変わる）。
// wear（mode 0・2）：塗りが斜めに掻き消され、輪郭がかすれて点線になる。絵が消される終わり方。
render_mode unshaded, cull_disabled, shadows_disabled;

uniform int mode = 0;
uniform vec3 fill = vec3(0.91, 0.86, 0.85);
uniform vec3 ink = vec3(0.03, 0.03, 0.035);
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform float grow = 1.0;
uniform float wear = 0.0;
uniform float spikes = 11.0;
uniform float outline = 1.0;
uniform float roll = 0.0;

float h1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h1(i), h1(i + vec2(1.0, 0.0)), f.x), mix(h1(i + vec2(0.0, 1.0)), h1(i + vec2(1.0, 1.0)), f.x), f.y);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float boil = floor(phase * 8.0);
	vec2 p = UV - 0.5;
	float c = cos(roll);
	float s = sin(roll);
	p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	// 手描きの震え
	p += (vec2(vn(p * 7.0 + boil * 13.1 + seed), vn(p * 7.0 - boil * 7.7 + seed + 9.0)) - 0.5) * 0.035;
	float dashes = vn(vec2(atan(p.y, p.x) * 6.0 + seed, boil * 3.0 + length(p) * 20.0));
	bool keep = false;
	bool is_ink = false;
	if (mode == 0) {
		float a = atan(p.y, p.x) / 6.2832 + 0.5;
		float r = length(p) * 2.0;
		float cell = floor(a * spikes);
		float t = fract(a * spikes);
		float reach = mix(0.38, 1.0, h1(vec2(cell, seed)));
		float tri = pow(1.0 - abs(t - 0.5) * 2.0, 2.4);     // 大きいほど細く鋭い棘
		float rad = (0.2 + (reach - 0.2) * tri) * grow * 0.95;
		float d = r - rad;
		float w = 0.03 + 0.02 * vn(p * 20.0 + boil);
		if (d < -w) {
			keep = true;
			// 斜めハッチングの影（右下の縁寄り）
			float shade = step(0.04, p.x + p.y * 0.6);
			float lines = step(0.55, fract((p.x - p.y) * 26.0)) * step(0.35, vn(p * 9.0 + seed));
			if (shade * lines > 0.5 && d > -0.24) {
				is_ink = true;
			}
			// 塗りが斜めに掻き消される
			if (vn(vec2((p.x + p.y) * 30.0, (p.x - p.y) * 3.0 + seed)) < wear * 1.7) {
				keep = false;
			}
		}
		if (abs(d) < w) {
			keep = dashes >= wear * 1.3 - 0.15;
			is_ink = true;
		}
		// 二重の下書き線（とぎれとぎれ）
		if (abs(d - 0.07) < 0.012 && dashes > 0.55 && wear < 0.5) {
			keep = true;
			is_ink = true;
		}
	} else if (mode == 1) {
		float x = p.x + 0.5;
		float zig = (abs(fract(x * 3.0 + seed) - 0.5) - 0.25) * 0.5;
		float th = 0.1 * pow(max(sin(3.14159 * clamp(x, 0.0, 1.0)), 0.0), 0.6) + 0.004;
		float d = abs(p.y - zig) - th;
		if (x < grow && x > wear && d < 0.0) {
			keep = true;
			is_ink = outline > 0.5 && d > -0.018;
		}
	} else if (mode == 3) {
		vec2 q = vec2(p.x, -p.y);
		float x = q.x + 0.5;
		float env = pow(max(sin(3.14159 * clamp(x, 0.0, 1.0)), 0.0), 0.5);
		float yc = 0.22 * sin(3.14159 * x) - 0.1;
		float top = yc + 0.07 * env + 0.01 * vn(vec2(x * 20.0, seed));
		float tear = 0.2 * pow(vn(vec2(x * 18.0 + seed, 1.0)), 2.0) + 0.14 * step(0.7, vn(vec2(x * 30.0 + seed, 5.0)));
		float bottom = yc - (0.07 + tear) * env;
		if (x < grow && x > wear && q.y < top && q.y > bottom) {
			keep = true;
			is_ink = top - q.y < 0.016 || q.y - bottom < 0.016;
			// 布のしわ
			if (abs(fract((q.y - yc) * 13.0 + vn(vec2(x * 6.0, seed)) * 2.0) - 0.5) < 0.05 && vn(vec2(x * 9.0, seed + 2.0)) > 0.62) {
				is_ink = true;
			}
		}
	} else if (mode == 4) {
		vec2 q = vec2(p.x, -p.y);
		float d = seg(q, vec2(-0.3, -0.2), vec2(0.3, -0.2));
		d = min(d, seg(q, vec2(-0.3, -0.2), vec2(-0.34, 0.18)));
		d = min(d, seg(q, vec2(-0.34, 0.18), vec2(-0.16, -0.02)));
		d = min(d, seg(q, vec2(-0.16, -0.02), vec2(0.0, 0.26)));
		d = min(d, seg(q, vec2(0.0, 0.26), vec2(0.16, -0.02)));
		d = min(d, seg(q, vec2(0.16, -0.02), vec2(0.34, 0.18)));
		d = min(d, seg(q, vec2(0.34, 0.18), vec2(0.3, -0.2)));
		bool stroke = d < 0.03 + 0.015 * vn(q * 12.0 + seed) && q.x + 0.5 < grow * 2.0;
		float drip = clamp(grow * 2.0 - 1.0, 0.0, 1.0);
		float dd = seg(q, vec2(-0.2, -0.2), vec2(-0.2, -0.2 - 0.12 * drip));
		dd = min(dd, seg(q, vec2(0.05, -0.2), vec2(0.05, -0.2 - 0.24 * drip)));
		dd = min(dd, seg(q, vec2(0.24, -0.2), vec2(0.24, -0.2 - 0.16 * drip)));
		if (stroke || (drip > 0.0 && dd < 0.018)) {
			keep = vn(vec2((q.x + q.y) * 26.0, (q.x - q.y) * 3.0 + seed)) >= wear * 1.6;
		}
	} else if (mode == 5) {
		vec2 q = vec2(p.x, -p.y);
		float u = (q.y + 0.5) / max(grow, 0.001);
		float xc = 0.07 * sin(u * 2.5 + seed) * u;
		float d = abs(q.x - xc) - 0.17 * (1.0 - u);
		float snapped = floor(wear * 3.0 + 0.001) / 3.0;
		bool broken = u > 1.0 - snapped + 0.07 * (fract(q.x * 9.0 + seed) - 0.5);
		if (u > 0.0 && u < 1.0 && d < 0.0 && !broken) {
			keep = true;
			is_ink = d > -0.022;
			if (q.x - xc > 0.015 && fract((q.x + q.y) * 24.0) > 0.55 && vn(q * 9.0 + seed) > 0.3) {
				is_ink = true;
			}
		}
	} else {
		vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071;
		float bar1 = max(abs(q.x) - 0.36 * grow, abs(q.y) - 0.1);
		float bar2 = max(abs(q.y) - 0.36 * grow, abs(q.x) - 0.1);
		float d = min(bar1, bar2);
		if (d < 0.0) {
			keep = vn(p * 14.0 + seed) >= wear * 1.2;
			is_ink = d > -0.025;
		}
	}
	if (!keep) {
		discard;
	}
	ALBEDO = is_ink ? ink : fill;
}
