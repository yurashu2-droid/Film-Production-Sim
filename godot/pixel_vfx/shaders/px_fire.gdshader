shader_type spatial;
// ドット絵の炎。板の上を res×res のマスに区切り、マスごとに熱を計算して5色に塗る。輪郭線つき。
// 1より大きい色を渡すと、ドット絵のまま本物の光としてにじむ。
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://pixel_vfx/shaders/px_common.gdshaderinc"

uniform float res = 48.0;           // ドット絵の解像度（1辺のマス数）
uniform float fps = 12.0;           // コマ打ちの速さ
uniform float phase = 0.0;
uniform float fuel = 1.0;           // 炎の高さ（0 で消える）
uniform float rise = 9.0;           // 模様が昇る速さ（マス/秒）
uniform float seed = 0.0;
uniform vec3 pal_0 = vec3(1.2, 0.08, 0.02);
uniform vec3 pal_1 = vec3(3.0, 0.45, 0.04);
uniform vec3 pal_2 = vec3(5.0, 1.6, 0.1);
uniform vec3 pal_3 = vec3(7.0, 4.2, 0.5);
uniform vec3 pal_4 = vec3(9.0, 8.0, 5.0);
uniform vec3 outline = vec3(0.12, 0.01, 0.02);
uniform float nudge = 0.0;          // カメラ側へ寄せる距離。同じ場所に重ねた層の前後を決める

void vertex() {
	// 縦軸だけカメラを向く
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX[3].z += nudge;
}

// マスの熱（0 以下は炎の外）
float heat(vec2 cell, float t) {
	vec2 p = (cell + 0.5) / res;
	float x = (p.x - 0.5) * 2.0;
	float y = 1.0 - p.y;                       // 0＝根元、1＝先
	float h = max(fuel, 0.02);
	float n = px_fbm(vec2(cell.x * 0.17 + seed, cell.y * 0.12 + t * rise * 0.12));
	float lick = px_noise(vec2(cell.x * 0.35 + seed * 3.0, cell.y * 0.2 + t * rise * 0.2));
	float sway = (n - 0.5) * 0.55 * y;
	float body = 1.0 - abs(x + sway) / max(0.62 - 0.5 * y / h, 0.02);
	float v = body * 1.1 + (n - 0.5) * 0.8 + (lick - 0.5) * 0.35 - y / h * 0.6;
	return (y > h * 1.15 || p.y > 0.98) ? -1.0 : v;
}

void fragment() {
	vec2 cell = floor(UV * res);
	float t = floor(phase * fps) / fps;
	float v = heat(cell, t);
	if (v <= 0.2) {
		// まわりのマスが炎なら、ここは輪郭線
		float around = max(max(heat(cell + vec2(1.0, 0.0), t), heat(cell - vec2(1.0, 0.0), t)), max(heat(cell + vec2(0.0, 1.0), t), heat(cell - vec2(0.0, 1.0), t)));
		if (around <= 0.2) {
			discard;
		}
		ALBEDO = outline;
	} else {
		ALBEDO = px_ramp((v - 0.2) / 0.85, cell, pal_0, pal_1, pal_2, pal_3, pal_4);
	}
}
