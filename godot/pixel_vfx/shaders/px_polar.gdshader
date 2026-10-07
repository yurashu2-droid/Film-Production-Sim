shader_type spatial;
// ドット絵の輪。円を res×res のマスで描く。
//   mode 0  渦の輪（ポータルの層）：流れる帯を5色で塗る
//   mode 1  魔法陣：同心の線と、輪ごとに回る目盛り
//   mode 2  奥の闇：暗い円に、またたく星のマス
// fill を下げると、マスの小さな区画ごとに点滅して消えていく（一斉に消えない）。
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://pixel_vfx/shaders/px_common.gdshaderinc"

uniform int mode = 0;
uniform float res = 48.0;
uniform float fps = 12.0;
uniform float phase = 0.0;
uniform float inner = 0.45;         // 輪の内側の半径（0〜1）
uniform float outer = 0.95;
uniform float spin = 1.0;           // 回る速さ（向きは符号）
uniform float twist = 2.5;          // 渦の巻き
uniform float bands = 5.0;
uniform float density = 0.5;        // 帯の詰まり具合
uniform float fill = 1.0;
uniform float seed = 0.0;
uniform bool billboard = false;
uniform vec3 pal_0 = vec3(0.05, 0.01, 0.2);
uniform vec3 pal_1 = vec3(0.3, 0.05, 1.2);
uniform vec3 pal_2 = vec3(1.2, 0.3, 3.5);
uniform vec3 pal_3 = vec3(2.0, 2.5, 7.0);
uniform vec3 pal_4 = vec3(7.0, 9.0, 10.0);

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	vec2 cell = floor(UV * res);
	vec2 p = ((cell + 0.5) / res - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = floor(phase * fps) / fps;
	// 区画ごとの点滅消し：4マス四方をひとまとまりにして、fill より大きい乱数の区画から消える
	float block = px_hash(floor(cell / 4.0) + seed * 13.0);
	if (r > 1.0 || block > fill * 1.02) {
		discard;
	}
	if (mode == 2) {
		if (r > outer) {
			discard;
		}
		float star = px_hash(cell + floor(t * 3.0 + px_hash(cell) * 5.0));
		vec3 col = mix(pal_0 * 0.4, pal_0, step(px_bayer(cell), r / outer));
		ALBEDO = star > 0.975 ? pal_4 : (star > 0.95 ? pal_2 : col);
	} else if (mode == 1) {
		// 同心の線：太い外輪、細い内輪、そのあいだに目盛り
		float ring = 0.0;
		ring = max(ring, step(abs(r - 0.93), 0.035));
		ring = max(ring, step(abs(r - 0.7), 0.02));
		ring = max(ring, step(abs(r - 0.36), 0.025));
		float turn = a / 6.2832 + t * spin * 0.08;
		float ticks = step(0.5, fract(turn * 24.0)) * step(abs(r - 0.815), 0.07);
		float runes = step(0.55, px_hash(vec2(floor((a / 6.2832 - t * spin * 0.05) * 16.0), floor(r * 12.0)) + seed)) * step(abs(r - 0.53), 0.11);
		float lit = max(ring, max(ticks, runes));
		if (lit < 0.5) {
			discard;
		}
		float pulse = 0.5 + 0.5 * sin(t * 6.0 - r * 8.0);
		ALBEDO = px_ramp(0.45 + 0.5 * pulse, cell, pal_0, pal_1, pal_2, pal_3, pal_4);
	} else {
		if (r < inner || r > outer) {
			discard;
		}
		float k = (r - inner) / max(outer - inner, 0.001);        // 0＝内、1＝外
		float flow = px_fbm(vec2(a / 6.2832 * bands * 2.0 + r * twist - t * spin, r * 5.0 + seed));
		float edge = min(k, 1.0 - k) * 3.0;
		float v = flow + min(edge, 1.0) * 0.35 - (1.0 - density);
		if (v < 0.22) {
			discard;
		}
		ALBEDO = px_ramp((v - 0.22) / 0.7 * (1.0 - 0.45 * k), cell, pal_0, pal_1, pal_2, pal_3, pal_4);
	}
}
