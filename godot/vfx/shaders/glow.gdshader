shader_type spatial;
// 加算で光る板。形は式で描く（0: 丸い光、1: 衝撃波の輪、2: 十字の閃光）。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform int shape = 0;
uniform vec4 color = vec4(1.0);
uniform float ring_width = 0.2;
uniform bool billboard = true;
uniform float toward_camera = 0.0;   // 手前へ寄せる距離（見かけの大きさは保つ）。大きな閃光が床で切れるのを防ぐ

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		float away = max(-MODELVIEW_MATRIX[3].z, 0.01);
		float near = clamp((away - toward_camera) / away, 0.1, 1.0);
		MODELVIEW_MATRIX[3].xyz *= near;
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz) * near, 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz) * near, 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float soft = max(1.0 - r, 0.0);
	float a = soft * soft;
	if (shape == 1) {
		// 外側はくっきり、内側へ尾を引く輪
		a = smoothstep(1.0 - ring_width, 1.0 - ring_width * 0.3, r) * smoothstep(1.0, 0.96, r);
	} else if (shape == 2) {
		float spikes = 0.012 / (abs(p.x) * abs(p.y) + 0.012);
		a = pow(soft, 4.0) + spikes * soft * 0.6;
	}
	ALBEDO = color.rgb * COLOR.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * color.a * COLOR.a;
}
