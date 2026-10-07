shader_type spatial;
// スミア（伸びる残像）。キャラと同じメッシュをもう一度描いて、後ろへ引き伸ばす。色はキャラ自身の色。
//   whole = false：いまのポーズ。進む向きの反対を向いた面だけを、尖った歯の形に伸ばし、伸びた部分だけ残す
//   whole = true ：少し前のポーズの写し（マルチプル）。全身を描き、網点で薄くする
// 伸びた先は edge_color → tip_color に塗る（白い輪郭、または雷の光）。
// 薄さは半透明ではなく、漫画のスクリーントーンのような網点で出す。
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords;

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 smear_dir = vec3(0.0, 0.0, 1.0);   // 伸ばす向き（ワールド）
uniform float amount = 0.0;                      // 伸ばす長さ（m）
uniform float step_seed = 0.0;                   // 変えるたびに歯の出方が変わる（コマ打ち用）
uniform float brightness = 0.95;
uniform float band_density = 6.0;                // 高さ1mあたりの歯の数
uniform float sharpness = 2.2;                   // 歯の尖り。大きいほど細く鋭い
uniform float zigzag = 0.0;                      // 歯を上下に折る強さ（雷らしいぎざぎざ）
uniform vec3 edge_color = vec3(1.7);             // 伸びた先の色
uniform vec3 tip_color = vec3(1.7);              // いちばん先の色
uniform float ghost_tint = 0.0;                  // 写しを edge_color に寄せる割合
uniform bool whole = false;
uniform float ghosting = 0.0;                    // 写しの薄さ（0 濃い 〜 1 見えない）
uniform float strength = 1.0;                    // 全体の出具合（速さで変える）
uniform float dot_size = 5.0;                    // 網点の間隔（ピクセル）
uniform float cut_above = 100000.0;              // この高さ（ワールドY）より上は描かない。脚だけ重ねる時に使う

varying float pull;
varying float world_y;

float hash(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void vertex() {
	float facing = max(dot(normalize(NORMAL), smear_dir), 0.0);
	// 高さごとに歯を1本ずつ立てる。同じ高さの頂点は同じだけ伸びるので、まとまった形になる
	float band = VERTEX.y * band_density + step_seed * 3.7;
	float cell = floor(band);
	float tooth = pow(1.0 - abs(fract(band) - 0.5) * 2.0, sharpness);
	pull = smoothstep(0.05, 0.6, facing) * tooth * mix(0.3, 1.0, hash(cell));
	world_y = VERTEX.y;
	VERTEX += smear_dir * pull * amount;
	VERTEX.y += pull * amount * zigzag * (hash(cell + step_seed * 1.3) - 0.5) * 2.0;
}

void fragment() {
	if (amount < 0.01 || world_y > cut_above || (!whole && pull < 0.03)) {
		discard;
	}
	// 残す割合：写しは薄く。伸びた先は輪郭を残したいので、あまり薄くしない
	float keep = strength * (1.0 - ghosting) * (1.0 - pull * (whole ? 0.75 : 0.25));
	// 45度に傾けた網点。keep が小さいほど点が小さくなる
	vec2 g = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * FRAGCOORD.xy / dot_size;
	float d = length(fract(g) - 0.5);
	if (d > sqrt(clamp(keep, 0.0, 1.0)) * 0.72) {
		discard;
	}
	vec3 c = texture(albedo_texture, UV).rgb * albedo.rgb * brightness;
	if (whole) {
		c = mix(c, edge_color, ghost_tint);
	} else {
		c = mix(c, edge_color, smoothstep(0.3, 0.55, pull));
		c = mix(c, tip_color, smoothstep(0.65, 0.9, pull));
	}
	ALBEDO = c;
}
