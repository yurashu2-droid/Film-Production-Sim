// 青いホログラム・人物用（講師バズ山。scripts/buzzyama_visual.gd の holo_dress が付ける）
// hologram.gdshader との違い：
//   ・モデルの絵の明るさを、青の濃淡に写す（サングラスは暗く、金の枠と縄は明るく）。全部が同じ青だと、顔が読めない
//   ・奥の面が透けて重ならない。体の向こうの縄や小石が、体に重なって見えない
//     やり方：半透明で混ぜずに、細かい点を抜いて透かす（alpha hash）。不透明の物として描くので、奥行きが普通に効く。
//     奥行きだけを先に書く別の面を足す方法は、ゲームの画面（MSAA あり）では本体が薄く消えて、使えなかった
// 呼ぶ側が入れる値（strength・flicker・tint）は、hologram.gdshader と同じ名前
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.30, 0.70, 1.0, 1.0);
uniform float strength = 1.0;      // 全体の濃さ（出てくる・消えるときに 0 ↔ 1）
uniform float base_alpha = 0.86;   // 正面から見たときの濃さ
uniform float flicker = 0.35;      // ちらつきの強さ
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	float scan = 0.62 + 0.38 * step(0.5, fract(world_pos.y * 16.0 - TIME * 1.2));
	float blink = 1.0 - flicker * step(0.93, fract(sin(floor(TIME * 12.0)) * 43758.5453));
	float lum = dot(texture(albedo_tex, UV).rgb, vec3(0.30, 0.59, 0.11));
	float v = pow(clamp(lum, 0.0, 1.0), 0.6);
	vec3 body = tint.rgb * mix(0.06, 1.5, v);
	ALBEDO = mix(body, vec3(1.0), rim * 0.45);
	// 暗い所（レンズ・口）ほど濃く。明るい所は、少し透ける
	ALPHA = clamp((base_alpha + 0.14 * (1.0 - v) + 0.3 * rim) * scan * blink * strength, 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;      // 透け方は、細かい点の抜きで出す（下の説明）
}
