shader_type spatial;
// 筆で引いたような線。光らせず、色をそのまま塗る。両端が細る。
// vfx_ribbon.gd の帯に使う（NORMAL に進行方向、UV.x に線上の位置、UV.y に左右）。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform float width = 0.05;
uniform vec4 color = vec4(1.25, 1.25, 1.25, 0.92);   // グローの閾値より下に保つ
uniform float fade = 1.0;

void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 t = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 view = PROJECTION_MATRIX[3][3] == 0.0 ? normalize(p) : vec3(0.0, 0.0, -1.0);
	vec3 side = cross(t, view);
	side = dot(side, side) > 0.000001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	VERTEX = p + side * (UV.y - 0.5) * width * pow(sin(3.14159 * clamp(UV.x, 0.0, 1.0)), 0.7);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a * fade;
}
