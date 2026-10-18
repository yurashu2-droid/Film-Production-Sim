// スプレーの霧の円すい（features/spray_sign.gd）。円すいの側面（ふたなし）に貼る。
// 参考：godotshaders の Fake Godrays（円すい＋ノイズ＋長さの透明度＋縁のフレネル）、
//       Jet Thruster（模様を流す・物の座標で先端と縁を薄くする）。docs/production/spray-paint-study.md
// 物の座標：y が +0.5 で缶の口（細い方）、-0.5 で板（太い方）。t＝口からの距離（0〜1）
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 paint : source_color = vec4(0.8, 0.1, 0.1, 1.0);
uniform float density = 0.55;      // 濃さ（内の円すいは濃く、外は薄く）
uniform float flow = 2.4;          // 模様が口から板へ流れる速さ
uniform float grow = 1.0;          // 吹き始め：口から先へ伸びる（0〜1）
uniform float cut = 0.0;           // 止めたあと：口の側から供給が切れていく（0〜1。1で全部抜けた）
uniform sampler2D noise : filter_linear, repeat_enable;      // ミップマップは使わない（一周の継ぎ目で縮小版が選ばれて、線が出るため）
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 obj;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float t = clamp(0.5 - obj.y, 0.0, 1.0);
	float ang = atan(obj.z, obj.x) / 6.2831853;
	// 模様：周りの向きと長さ方向で引き、口から板へ流す（2つの大きさを重ねて、粒っぽく）
	float n1 = texture(noise, vec2(ang * 3.0, t * 1.6 - TIME * flow)).r;
	float n2 = texture(noise, vec2(ang * 7.0 + 0.37, t * 4.0 - TIME * flow * 1.7)).r;
	float mist = smoothstep(0.25, 0.85, n1 * 0.6 + n2 * 0.55);
	// 縁を消す（面を斜めに見る所ほど薄い）
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(facing, 1.6);
	// 長さ：口のすぐ先が濃く、板の手前で薄くなる。伸びている途中は、先が無い
	// 口のすぐ先は細すぎて線に見えるので、少し離れた所からふわっと現れる
	float along = smoothstep(0.08, 0.5, t) * (1.0 - smoothstep(0.75, 1.0, t)) * (1.0 - t * 0.25);
	along *= 1.0 - smoothstep(grow - 0.08, grow, t);
	// 止めたあと：口の側から消えていき、残りは板の方へ抜ける
	along *= smoothstep(cut, cut + 0.12, t);
	// 板と交わる所は、奥行きの差で柔らかく（交わりの線を出さない）
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float behind = -world.z / world.w;
	float soft = clamp((behind - (-VERTEX.z)) / 0.06, 0.0, 1.0);
	ALBEDO = paint.rgb;
	ALPHA = clamp(density * mist * edge * along * soft, 0.0, 1.0);
}
