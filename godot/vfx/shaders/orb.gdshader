shader_type spatial;
// 弾の頭を包むオーラ。球を進行方向に伸ばして使う。後ろ（+Z）へ流れるノイズで炎のように千切れる。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec4 color = vec4(4.0, 1.5, 0.3, 1.0);
uniform float speed = 3.0;
uniform float cut = 0.42;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float back = smoothstep(-0.5, 0.5, local_pos.z);
	float n = texture(noise_texture, vec2(atan(local_pos.x, local_pos.y) / 6.2832 * 2.0, local_pos.z * 0.7 - TIME * speed)).r;
	float a = smoothstep(cut + back * 0.3, cut + back * 0.3 + 0.07, n * (0.45 + 0.7 * rim) + (1.0 - back) * 0.3);
	ALBEDO = color.rgb;
	ALPHA = a * color.a;
}
