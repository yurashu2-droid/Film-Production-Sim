shader_type spatial;
// 念力の筋：手から物へ流れる「気」の線（vfx_psychic.gd）。vfx_ribbon.gd の帯に使う。
// UV.x は 0＝手 〜 1＝物。線の上を濃淡のかたまりが物のほうへ流れ、かたまりの所で太くなる（太さを一定にしない）。
// 加算ではなく普通の塗り。色は淡く、グローの閾値（1.6）をほとんど超えない。
//   head  手からここまで伸びている ／ tail  手からここまで消えた（供給が止まると、根元から先へ消える）
//   soft  1 にすると、芯のない太いもやの帯になる
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float width = 0.04;
uniform vec3 color = vec3(0.7, 0.5, 1.2);
uniform vec3 color_core = vec3(1.4, 1.35, 1.55);
uniform float opacity = 0.85;
uniform float phase = 0.0;        // 濃淡が物へ流れる位置
uniform float seed = 0.0;
uniform float stretch = 1.0;      // 濃淡のかたまりの数（線の長さに合わせて渡す）
uniform float cut = 0.4;          // 大きいほど途切れる（止まっている時は途切れがち、動かすとつながる）
uniform float head = 1.0;
uniform float tail = 0.0;
uniform float soft = 0.0;

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
	ALPHA = smoothstep(cut, cut + 0.1, body) * edge * opacity;
}
