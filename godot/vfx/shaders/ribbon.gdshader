shader_type spatial;
// 点の列に沿う帯（弾の軌跡・稲妻）。頂点は中心線に置き、ここで画面に向けて幅を広げるので、
// どのカメラから見ても太さが出る。NORMAL に進行方向、UV.x に先頭からの位置、UV.y に左右を入れて渡す。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform float width = 0.3;
uniform vec4 color_head = vec4(4.0, 2.0, 0.5, 1.0);
uniform vec4 color_tail = vec4(1.0, 0.2, 0.0, 1.0);
uniform vec3 core_color = vec3(8.0);
uniform float core = 0.25;        // 白い芯の太さ（幅に対する割合）
uniform float taper = 0.8;        // 尾の細り
uniform float erosion = 1.0;      // 尾がノイズで千切れる強さ
uniform vec2 noise_scale = vec2(2.0, 1.0);
uniform float noise_speed = 2.0;
uniform float reveal = 1.0;       // 先頭からここまでだけ描く
uniform float fade = 1.0;

void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 t = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 view = PROJECTION_MATRIX[3][3] == 0.0 ? normalize(p) : vec3(0.0, 0.0, -1.0);
	vec3 side = cross(t, view);
	side = dot(side, side) > 0.000001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	VERTEX = p + side * (UV.y - 0.5) * width * mix(1.0, 1.0 - UV.x, taper);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float n = texture(noise_texture, vec2(UV.x * noise_scale.x - TIME * noise_speed, UV.y * noise_scale.y)).r;
	float body = smoothstep(1.0, 0.15, across);
	float torn = smoothstep(UV.x * erosion - 0.12, UV.x * erosion + 0.12, n + (1.0 - across) * 0.35);
	float hot = smoothstep(core + 0.06, core, across) * (1.0 - UV.x * taper);
	vec4 c = mix(color_head, color_tail, UV.x);
	ALBEDO = mix(c.rgb, core_color, hot);
	ALPHA = body * mix(1.0, torn, min(erosion, 1.0)) * c.a * fade * step(UV.x, reveal) * smoothstep(0.0, 0.04, UV.x);
}
