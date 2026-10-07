shader_type spatial;
// インパクトフレーム。画面に映っているものを白黒にして反転し、赤を少し差す（『呪術廻戦』の黒閃で、当たった瞬間に絵が反転する表現）。
// 画面を覆う大きな板に貼り、1〜2コマだけ出す。ほかの効果より後に描く。
render_mode unshaded, cull_disabled, shadows_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount = 1.0;
uniform vec3 tint = vec3(1.0, 0.12, 0.1);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	// 明暗をはっきり2〜3段に分けてから反転する
	float hard = smoothstep(0.12, 0.5, grey);
	vec3 flipped = vec3(1.0 - hard);
	flipped = mix(flipped, tint, smoothstep(0.35, 0.65, hard) * (1.0 - smoothstep(0.65, 0.9, hard)) * 0.8);
	ALBEDO = mix(c, flipped, amount);
}
