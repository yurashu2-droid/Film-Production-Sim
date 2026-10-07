shader_type spatial;
// 様式化した煙・火球（チュートリアル「Stylized Smoke」の組み立て）。
// 雲の形のメッシュを、粒子の色で塗り、粒子のアルファを「溶け具合」に使って穴を開けて消す。
// 影は段で切る（セルシェーディング）。暗い現場でも形が読めるよう、光の向きは固定で持つ。
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D dissolve_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 texture_scale = vec2(1.2, 0.7);
uniform bool flat_style = false;                    // true で影の段をやめる（簡略版）
uniform vec3 light_dir = vec3(-0.35, 0.85, 0.4);
uniform float shadow_threshold = -0.1;
uniform float highlight_threshold = 0.6;
uniform float band_softness = 0.025;
uniform vec3 shadow_tint = vec3(0.5, 0.5, 0.62);
uniform vec3 highlight_tint = vec3(1.25, 1.22, 1.15);
uniform vec3 edge_color = vec3(0.0);               // 溶ける縁の焼け色
uniform float edge_width = 0.1;

varying vec3 world_normal;
varying float seed;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	seed = fract(float(INSTANCE_ID) * 0.618034);
}

void fragment() {
	float d = texture(dissolve_texture, UV * texture_scale + vec2(seed, seed * 1.7)).r;
	// 泡ノイズは0付近が多いので、少し溶け始めただけでは穴が開かないよう底上げする
	d = mix(0.1, 0.98, d);
	float cut = 1.0 - COLOR.a;
	if (d < cut) {
		discard;
	}
	vec3 n = normalize(world_normal);
	vec3 col = COLOR.rgb;
	if (!FRONT_FACING) {
		n = -n;
		col *= 0.6;
	}
	if (!flat_style) {
		float ndl = dot(n, normalize(light_dir));
		float lit = smoothstep(shadow_threshold - band_softness, shadow_threshold + band_softness, ndl);
		float hi = smoothstep(highlight_threshold - band_softness, highlight_threshold + band_softness, ndl);
		col *= mix(shadow_tint, vec3(1.0), lit);
		col = mix(col, col * highlight_tint, hi);
	}
	col += edge_color * smoothstep(cut + edge_width, cut, d) * step(0.002, cut);
	ALBEDO = col;
}
