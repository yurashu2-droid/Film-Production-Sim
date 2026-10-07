shader_type spatial;
// 筒の表面を炎が流れ昇る（火柱・オーラ）。UV.x は周方向、UV.y は 0＝根元 〜 1＝先端。
// 炎の絵とノイズを別の速さで流して掛け合わせ、明るさを4段に切って塗る（ぼかさない）。
//   grow       0〜1。根元からこの高さまで描く（立ち上がり）
//   eaten      0〜1。根元からこの高さまで消す（下からちぎれて消える終わり方）
// TIME は使わず phase で進める。コマ打ちは呼ぶ側で phase を刻む。
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D flame : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform float phase = 0.0;
uniform vec2 flame_scale = vec2(1.0, 0.45);
uniform vec2 flame_speed = vec2(0.05, 1.2);
uniform vec2 noise_scale = vec2(2.0, 0.8);
uniform vec2 noise_speed = vec2(-0.12, 0.7);
uniform float density = 1.0;          // 大きいほど炎が詰まる
uniform float tip_fade = 1.6;         // 先端へ向かって薄くなる強さ
uniform vec3 color_core = vec3(9.0, 8.0, 5.0);
uniform vec3 color_hot = vec3(7.0, 4.2, 0.5);
uniform vec3 color_mid = vec3(5.0, 1.4, 0.1);
uniform vec3 color_edge = vec3(2.2, 0.25, 0.03);
uniform float grow = 1.0;
uniform float eaten = 0.0;
uniform float wobble = 0.04;

void vertex() {
	float a = UV.x * 6.2832;
	VERTEX.xz *= 1.0 + wobble * sin(a * 3.0 + UV.y * 7.0 - phase * 5.0) * UV.y;
}

void fragment() {
	float f = texture(flame, UV * flame_scale - flame_speed * phase).r;
	float n = texture(noise_texture, UV * noise_scale - noise_speed * phase).r;
	float v = (f * 0.75 + n * 0.45) * density;
	v *= 1.0 - pow(UV.y, tip_fade);                 // 先端ほど炎がまばらになる
	v += (1.0 - UV.y) * 0.35 * (1.0 - eaten);        // 根元は詰まっている
	// 立ち上がりと、下からの消失。境目はノイズで舌の形にする
	float top = grow * 1.15 - UV.y + (n - 0.5) * 0.2;
	float bottom = UV.y - eaten * 1.25 + (f - 0.5) * 0.25;
	if (v < 0.34 || top < 0.0 || bottom < 0.0) {
		discard;
	}
	vec3 col = color_edge;
	col = v > 0.62 ? color_mid : col;
	col = v > 0.92 ? color_hot : col;
	col = v > 1.22 ? color_core : col;
	// 消えていく根元のふちは一段明るく（ちぎれ目が燃えている）
	col = (eaten > 0.01 && bottom < 0.04) ? color_hot : col;
	ALBEDO = col;
}
