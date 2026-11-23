shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;
varying flat vec3 sample_data;

void vertex() {
	sample_data = INSTANCE_CUSTOM.xyz;
	// 濃淡は砂そのものに持たせ、板はカメラ向きのまま横に伸びる。
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	if (sample_data.z <= 0.001) {
		discard;
	}
	vec2 cell = vec2(min(floor(sample_data.x * 16.0), 15.0), sample_data.y);
	vec4 dust = texture(sheet, (cell + clamp(UV, vec2(0.022), vec2(0.978))) / 16.0);
	float soft_edge = smoothstep(0.15, 0.80, dust.a);
	ALBEDO = mix(vec3(0.38, 0.27, 0.17), vec3(0.94, 0.77, 0.54), dust.r);
	ALPHA = sample_data.z * soft_edge * 0.68;
}
