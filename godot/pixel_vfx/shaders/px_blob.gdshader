shader_type spatial;
// ドット絵の小さな絵。カメラ向き（lie_flat = true で向きを固定。地面に寝かせる時など）。
//   mode 0  煙玉：ふちの欠けた丸。fade を上げると網点で薄れていく
//   mode 1  閃光：十字の星
//   mode 2  地面の光：丸い網点のグラデーション
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://pixel_vfx/shaders/px_common.gdshaderinc"

uniform int mode = 0;
uniform float res = 16.0;
uniform float fade = 0.0;
uniform float seed = 0.0;
uniform bool lie_flat = false;
uniform vec3 color = vec3(0.5, 0.5, 0.55);
uniform vec3 shade = vec3(0.25, 0.25, 0.3);
uniform vec3 outline = vec3(0.08, 0.08, 0.1);

void vertex() {
	if (!lie_flat) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
}

float body(vec2 cell) {
	vec2 p = ((cell + 0.5) / res - 0.5) * 2.0;
	float r = length(p);
	if (mode == 1) {
		return max(1.0 - r * 1.6, (1.0 - r) * step(min(abs(p.x), abs(p.y)), 0.14 * (1.0 - r) + 0.5 / res));
	}
	if (mode == 2) {
		return 1.0 - r;
	}
	return 0.82 - r + (px_noise(cell * 0.45 + seed) - 0.5) * 0.35;
}

void fragment() {
	vec2 cell = floor(UV * res);
	float v = body(cell);
	if (mode == 2) {
		if (v <= 0.0 || px_bayer(cell) > v * 1.4 * (1.0 - fade)) {
			discard;
		}
		ALBEDO = color;
	} else {
		if (px_bayer(cell + seed) < fade) {
			discard;
		}
		if (v <= 0.0) {
			float around = max(max(body(cell + vec2(1.0, 0.0)), body(cell - vec2(1.0, 0.0))), max(body(cell + vec2(0.0, 1.0)), body(cell - vec2(0.0, 1.0))));
			if (around <= 0.0 || mode == 1) {
				discard;
			}
			ALBEDO = outline;
		} else {
			vec2 p = ((cell + 0.5) / res - 0.5) * 2.0;
			ALBEDO = (mode == 0 && p.y - p.x * 0.5 > 0.15) ? shade : color;
		}
	}
}
