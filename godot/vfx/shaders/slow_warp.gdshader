// スロー光線・超能力の型：届く範囲の円すいを、空間のゆがみで見せる（制作班にだけ見える層に置く）。
// 円すいの面を通して見える景色が、ゆっくり波打つ。縁ほど強く、色も少しずれる。光る筋や粒は出さない。
//   grow：0→1 で、根元から先へ伸びる／eaten：0→1 で、根元から先へ消える／power：強さ
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float grow = 1.0;
uniform float eaten = 0.0;
uniform float power = 1.0;
uniform float t = 0.0;
uniform float height = 9.0;
uniform float bend = 0.022;            // ゆがみの大きさ（画面の幅を 1 として）
uniform vec3 tint = vec3(0.62, 0.5, 1.0);

varying float along;
varying vec3 lp;

float ih(ivec2 c) {
	uint n = uint(c.x) * 374761393u + uint(c.y) * 668265263u;
	n = (n ^ (n >> 13u)) * 1274126177u;
	n = n ^ (n >> 16u);
	return float(n & 0xffffu) / 65535.0;
}

float vn(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	return mix(mix(ih(c), ih(c + ivec2(1, 0)), f.x), mix(ih(c + ivec2(0, 1)), ih(c + ivec2(1, 1)), f.x), f.y);
}

void vertex() {
	along = 0.5 - VERTEX.y / height;
	lp = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.3);
	float ang = atan(lp.x, lp.z) / TAU;
	float window = smoothstep(eaten - 0.03, eaten + 0.1, along) * (1.0 - smoothstep(grow - 0.1, grow + 0.02, along)) * smoothstep(0.015, 0.1, along) * (1.0 - smoothstep(0.82, 1.0, along));
	float k = (0.3 + 0.7 * rim) * window * power;
	if (k < 0.004) {
		discard;
	}
	// 大きいうねりは遅く、細かいうねりは速く。根元から先へ流れる
	vec2 big = vec2(vn(vec2(ang * 5.0 + 1.7, along * 3.5 - t * 0.09)), vn(vec2(ang * 5.0 + 8.3, along * 3.5 - t * 0.075))) - 0.5;
	vec2 fine = vec2(vn(vec2(ang * 13.0 - 4.1, along * 9.0 - t * 0.2)), vn(vec2(ang * 13.0 + 2.9, along * 9.0 - t * 0.17))) - 0.5;
	vec2 off = (big * 0.75 + fine * 0.25) * bend * k * 2.0;
	vec3 c;
	c.r = texture(screen_tex, SCREEN_UV + off * 1.35).r;
	c.g = texture(screen_tex, SCREEN_UV + off).g;
	c.b = texture(screen_tex, SCREEN_UV + off * 0.65).b;
	// 縁にだけ、うすい紫（面の中は、ほぼ素通し）
	c = mix(c, c * vec3(0.93, 0.88, 1.1) + tint * 0.05, clamp(rim * k * 1.4, 0.0, 0.7));
	ALBEDO = c;
	ALPHA = 1.0;
}
