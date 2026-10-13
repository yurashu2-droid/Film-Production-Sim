shader_type spatial;
// 念力の線：手から物へ飛ぶ念波の弧と、手と物をつなぐ薄いもやの筋（vfx_psychic.gd）。vfx_ribbon.gd の帯に使う。
// UV.x は 0＝根元 〜 1＝先。線の上を濃淡のかたまりが先へ流れ、かたまりの所で太くなる（太さを一定にしない）。
// 加算ではなく普通の塗り。色は淡く、グローの閾値（1.6）をほとんど超えない。
//   head  根元からここまで伸びている ／ tail  根元からここまで消えた（供給が止まると、根元から先へ消える）
//   soft  1 にすると、芯のない太いもやの帯になる（途切れさせず、濃淡だけ流す）
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float width = 0.04;
uniform vec3 color = vec3(0.7, 0.5, 1.2);
uniform vec3 color_core = vec3(1.4, 1.35, 1.55);
uniform float opacity = 0.85;
uniform float phase = 0.0;        // 濃淡が先へ流れる位置
uniform float seed = 0.0;
uniform float stretch = 1.0;      // 濃淡のかたまりの数（線の長さに合わせて渡す）
uniform float cut = 0.4;          // 大きいほど途切れる（soft＝0 の線だけ）
uniform float head = 1.0;
uniform float tail = 0.0;
uniform float soft = 0.0;
uniform float near_fade = 0.0;    // 1 にすると、カメラのすぐ近く（一人称の手もと）では薄くする（目の前を線が横切らないように）

varying float away;

void vertex() {
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 t = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 view = PROJECTION_MATRIX[3][3] == 0.0 ? normalize(p) : vec3(0.0, 0.0, -1.0);
	vec3 side = cross(t, view);
	side = dot(side, side) > 0.000001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float u = clamp(UV.x, 0.0, 1.0);
	float lump = textureLod(noise_tex, vec2(u * stretch - phase, seed), 0.0).r;
	// いま描いている範囲（tail〜head）の両端で細る
	float span = clamp((u - tail) / max(head - tail, 0.001), 0.0, 1.0);
	float w = width * pow(sin(3.14159 * span), 0.55) * (0.4 + 1.2 * lump);
	VERTEX = p + side * (UV.y - 0.5) * w;
	NORMAL = vec3(0.0, 0.0, 1.0);
	away = -p.z;
}

void fragment() {
	float u = UV.x;
	if (u > head || u < tail) {
		discard;
	}
	float across = abs(UV.y - 0.5) * 2.0;
	float a = texture(noise_tex, vec2(u * stretch - phase, seed)).r;
	float b = texture(noise_tex, vec2(u * stretch * 2.3 - phase * 1.7, seed + 0.31 + UV.y * 0.12)).r;
	float body = a * 0.7 + b * 0.5;
	float edge = mix(smoothstep(1.0, 0.6, across), pow(max(1.0 - across, 0.0), 1.6), soft);
	float core = (1.0 - soft) * smoothstep(0.6, 0.2, across) * smoothstep(cut + 0.08, cut + 0.3, body);
	ALBEDO = mix(color, color_core, core);
	ALPHA = mix(smoothstep(cut, cut + 0.1, body), 0.5 + 0.5 * smoothstep(0.25, 0.8, body), soft) * edge * opacity;
	ALPHA *= mix(1.0, smoothstep(0.7, 1.7, away), near_fade);
}
