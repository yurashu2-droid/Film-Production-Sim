shader_type spatial;
// ドット絵の光の柱。マスの列ごとに高さと速さが違い、光るマスが下から上へ流れる。
// grow で立ち上がり、close を上げると列がひとつずつ消える。
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://pixel_vfx/shaders/px_common.gdshaderinc"

uniform vec2 res = vec2(20.0, 64.0);
uniform float fps = 12.0;
uniform float phase = 0.0;
uniform float grow = 1.0;
uniform float close = 0.0;
uniform float seed = 0.0;
uniform vec3 pal_0 = vec3(0.02, 0.2, 0.5);
uniform vec3 pal_1 = vec3(0.1, 0.8, 1.8);
uniform vec3 pal_2 = vec3(0.4, 2.2, 4.0);
uniform vec3 pal_3 = vec3(2.0, 5.5, 8.0);
uniform vec3 pal_4 = vec3(8.0, 10.0, 10.0);

void vertex() {
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
}

void fragment() {
	vec2 cell = floor(UV * res);
	float t = floor(phase * fps) / fps;
	float col_id = cell.x;
	float x = abs((cell.x + 0.5) / res.x - 0.5) * 2.0;      // 0＝中心、1＝端
	float y = 1.0 - (cell.y + 0.5) / res.y;                 // 0＝根元
	float pick = px_hash(vec2(col_id, seed));
	// 列ごとの高さ。中心ほど高い
	float top = grow * (0.55 + 0.45 * pick) * (1.0 - 0.45 * x * x);
	if (y > top || pick < close) {
		discard;
	}
	// 上へ流れる光のマス。列ごとに速さが違う
	float run = floor(cell.y + t * (10.0 + 14.0 * pick));
	float spark = px_hash(vec2(col_id * 3.1 + seed, run));
	float v = (1.0 - x) * 0.75 + (spark > 0.7 ? 0.45 : 0.0) - y / max(top, 0.01) * 0.3;
	// 端は網点でまばらに
	if (px_bayer(cell) > (1.15 - x) * 1.4 && spark < 0.85) {
		discard;
	}
	ALBEDO = px_ramp(v, cell, pal_0, pal_1, pal_2, pal_3, pal_4);
}
