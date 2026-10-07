shader_type spatial;
// 発光ではなく、紙に描いたような不揃いの打撃マーク。輪郭を尖らせてから小さく畳む。
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 fill_color = vec3(1.4, 1.12, 0.53);
uniform vec3 ink = vec3(0.28, 0.13, 0.055);
uniform float turn = 0.0;
uniform float ink_width = 0.045;
uniform float toward_camera = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float away = max(-MODELVIEW_MATRIX[3].z, 0.01);
	float near_scale = clamp((away - toward_camera) / away, 0.1, 1.0);
	MODELVIEW_MATRIX[3].xyz *= near_scale;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz) * near_scale, 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz) * near_scale, 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * vec2(1.0, 1.13);
	float angle = atan(p.y, p.x) + turn;
	float spike = pow(max(cos(angle * 6.0), 0.0), 1.6);
	float radius = 0.25 + spike * (0.56 + 0.1 * sin(angle * 3.0 + 0.7));
	float distance_to_edge = radius - length(p);
	if (distance_to_edge < 0.0) {
		discard;
	}
	ALBEDO = mix(ink, fill_color, smoothstep(ink_width * 0.7, ink_width, distance_to_edge));
}
