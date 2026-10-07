shader_type spatial;
// 黒い稲妻。芯は真っ黒、ふちだけ赤く光る（『呪術廻戦』の黒閃）。加算ではなく普通の塗りなので、明るい場所でも黒が残る。
// vfx_ribbon.gd の帯に使う。reveal で先端から引っ込む。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform float width = 0.3;
uniform vec3 core_color = vec3(0.0, 0.0, 0.0);
uniform vec3 edge_color = vec3(9.0, 0.5, 0.3);
uniform float core = 0.55;         // 黒い芯の太さ（幅に対する割合）
uniform float taper = 0.8;
uniform float reveal = 1.0;        // 根元からここまで描く

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
	if (UV.x > reveal) {
		discard;
	}
	float across = abs(UV.y - 0.5) * 2.0;
	ALBEDO = across < core ? core_color : edge_color;
}
