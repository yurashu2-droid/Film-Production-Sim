shader_type spatial;
// 念力でつかんだ物の、輪郭の外にゆらめく「気」のふち（vfx_psychic.gd）。
// 物と同じメッシュを外へ少し膨らませ、裏側の面だけを描く。物そのものの上には重ならず、輪郭の外にだけ出る。
// 太さとすき間の違う殻を3枚重ねて使う（内は細く詰まって明るい／外は太くまばらで、上へ舌が伸びる）。
// 模様は「物の中心から見た画面の上の位置」で引くので、物を動かしても回しても模様は泳がない。
//   wipe_in   つかんだ点の側からここまで描く（包んでいく） ／ wipe_out  つかんだ点の側からここまで消す（流れ切る）
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, world_vertex_coords;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 center = vec3(0.0);          // 物の中心（ワールド）
uniform float width = 0.03;               // 輪郭から外へ出す長さ（m）
uniform float rise = 0.0;                 // 上向きの面を、さらに上へ伸ばす割合（炎の舌）
uniform float phase = 0.0;                // 模様が上へ流れる位置
uniform float seed = 0.0;
uniform float cut = 0.3;                  // 大きいほどすき間が増える
uniform float scale = 2.6;                // 模様の細かさ（1m あたりの繰り返し）
uniform vec3 color = vec3(0.7, 0.5, 1.2);
uniform float opacity = 0.9;
uniform vec3 wipe_from = vec3(0.0);
uniform vec3 wipe_dir = vec3(0.0, 1.0, 0.0);
uniform float wipe_in = 100.0;
uniform float wipe_out = -100.0;

varying vec3 wpos;

void vertex() {
	// 角ばった物は面ごとに法線が違い、法線だけで膨らますと角で殻が裂ける。中心から外への向きを半分まぜる
	vec3 radial = VERTEX - center;
	float far = length(radial);
	vec3 dir = NORMAL + (far > 0.0001 ? radial / far : NORMAL) * 0.85;
	dir = length(dir) > 0.05 ? normalize(dir) : NORMAL;
	// 遠くの物ほど少し太く（画面の上で細くなりすぎない）
	float w = width * clamp(distance(VERTEX, CAMERA_POSITION_WORLD) / 5.0, 0.7, 2.2);
	VERTEX += dir * w + vec3(0.0, w * rise * max(dir.y, 0.0), 0.0);
	wpos = VERTEX;
}

void fragment() {
	vec3 q = (VIEW_MATRIX * vec4(wpos - center, 0.0)).xyz;
	float a = texture(noise_tex, vec2(q.x * scale + seed, q.y * scale * 0.6 - phase)).r;
	float b = texture(noise_tex, vec2(q.x * scale * 2.1 - seed * 1.7, q.y * scale * 1.1 - phase * 1.6)).r;
	float along = dot(wpos - wipe_from, wipe_dir) + (b - 0.5) * 0.14;
	if (a * 0.65 + b * 0.45 < cut || along > wipe_in || along < wipe_out) {
		discard;
	}
	ALBEDO = color;
	ALPHA = opacity;
}
