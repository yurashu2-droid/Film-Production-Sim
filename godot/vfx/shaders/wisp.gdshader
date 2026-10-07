shader_type spatial;
// 重ねて使う、すき間だらけの薄い殻。1層は1色（＋内側の明るい筋）だけ。
// 何層も同じ軸に重ね、外を暗く・内を明るくすると、奥行きのある渦になる（1枚の殻を色分けすると固体に見える）。
// 絵は斜めに流して、巻き上がる帯の形にする。UV.x は周方向、UV.y は 0＝根元 〜 1＝先端。
//   grow   根元からこの高さまで描く ／ eaten  根元からこの高さまで消す
//   sway   全層で同じ値にすると、同じ軸のまま一緒にうねる
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D mask_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_b : filter_linear_mipmap, repeat_enable;
uniform float phase = 0.0;
uniform vec2 scale_a = vec2(1.0, 0.32);
uniform float shear = 0.75;              // 絵を斜めに倒す量（巻き上がる角度）
uniform vec2 speed_a = vec2(0.8, 0.4);
uniform vec2 scale_b = vec2(2.0, 0.7);
uniform vec2 speed_b = vec2(-0.3, 0.7);
uniform float cut = 0.6;                // 大きいほどすき間が増える
uniform float inner = 0.14;             // これだけ濃い所は明るい色で塗る
uniform float top_thin = 0.42;          // 先端ほどまばらにする
uniform float tip = 0.3;                // 上端を舌の形に欠く深さ（0 で欠かない。球や板では 0 にする）
uniform vec3 color = vec3(0.1, 0.4, 2.0);
uniform vec3 color_inner = vec3(0.4, 1.4, 4.0);
uniform float side_ragged = 0.0;        // 板に使うとき、左右のふちをぎざぎざに欠く深さ（0 で欠かない）
uniform float grow = 1.0;
uniform float eaten = 0.0;
uniform float sway = 0.12;
uniform float ripple = 0.05;
uniform float seed = 0.0;

void vertex() {
	float y = UV.y;
	VERTEX.xz *= 1.0 + ripple * sin(UV.x * 12.566 + y * 5.0 - phase * 3.0 + seed * 9.0);
	VERTEX.x += sin(phase * 2.2 + y * 3.1) * sway * y;
	VERTEX.z += cos(phase * 1.7 + y * 2.3) * sway * y;
}

void fragment() {
	vec2 ua = vec2(UV.x * scale_a.x + UV.y * shear + seed, UV.y * scale_a.y) - speed_a * phase;
	float a = texture(mask_a, ua).r;
	float b = texture(mask_b, UV * scale_b + vec2(seed * 1.7, 0.0) - speed_b * phase).r;
	float m = a * 0.7 + b * 0.45;
	float limit = cut + top_thin * pow(UV.y, 2.5);
	float top = grow * 1.12 - UV.y + (b - 0.5) * 0.25;
	float bottom = UV.y - eaten * 1.35 + (a - 0.5) * 0.3;
	// 上端：筒のふちが平らに見切れないよう、角度ごとに違う高さで終わらせる（舌はゆっくり形を変える）
	float tongue = texture(mask_b, vec2(UV.x * 2.0 + seed * 3.1, phase * 0.25 + seed)).r;
	float crest = 1.0 - tip * (0.2 + 0.8 * tongue) - tip * 0.5 * (1.0 - a);
	float side = abs(UV.x - 0.5) * 2.0;
	bool off_side = side_ragged > 0.0 && side > 1.0 - side_ragged * (0.15 + 0.85 * texture(mask_b, vec2(UV.y * 6.0 + seed, 0.37)).r);
	if (m < limit || top < 0.0 || bottom < 0.0 || UV.y > crest || off_side) {
		discard;
	}
	ALBEDO = m > limit + inner ? color_inner : color;
}
