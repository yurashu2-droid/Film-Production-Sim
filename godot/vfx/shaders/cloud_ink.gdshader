shader_type spatial;
// 煙の輪郭線。cloud シェーダーの材質の next_pass に付ける。
// 裏面だけを少し膨らませて描くと、手前の塊のふちに線が残る。溶ける穴の位置は cloud と同じにしてある。
render_mode unshaded, cull_front, shadows_disabled;

uniform sampler2D dissolve_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 texture_scale = vec2(1.2, 0.7);
uniform vec3 ink = vec3(0.2, 0.12, 0.06);
uniform float thickness = 0.04;      // 塊の直径に対する線の太さ

varying float seed;

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.618034);
	VERTEX += NORMAL * thickness;
}

void fragment() {
	float d = mix(0.1, 0.98, texture(dissolve_texture, UV * texture_scale + vec2(seed, seed * 1.7)).r);
	if (d < 1.0 - COLOR.a) {
		discard;
	}
	ALBEDO = ink;
}
