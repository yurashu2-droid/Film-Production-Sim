// スロー光線：届く範囲を示す、うすい円すい（制作班にだけ見える。映画には映らない層に置く）。
// 円すいの面に、根元から先へゆっくり流れる筋。先へ行くほど筋が細かくまばらになり、端に届く前に無くなる（面の端で切らない）。
//   grow ：0→1 で、根元から先へ伸びる（出した時）
//   eaten：0→1 で、根元から先へ消える（止めた時。光は、出どころが止まると根元から消える）
//   power：明るさ（出している＝1。持っているだけ＝弱く）
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float grow = 1.0;
uniform float eaten = 0.0;
uniform float power = 1.0;
uniform float t = 0.0;
uniform float height = 9.0;
uniform vec3 tint = vec3(0.5, 0.38, 1.0);

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
	along = 0.5 - VERTEX.y / height;        // 根元（とがった先）が 0、開いた口が 1
	lp = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	float ang = atan(lp.x, lp.z) / TAU;
	// 大きい筋は遅く、細かい筋は速く。斜めに巻きながら先へ流れる
	float big = vn(vec2(ang * 7.0 + along * 1.6, along * 4.0 - t * 0.10));
	float fine = vn(vec2(ang * 19.0 - along * 2.5, along * 10.0 - t * 0.21));
	float n = big * 0.62 + fine * 0.38;
	float th = mix(0.46, 0.93, pow(smoothstep(0.5, 1.0, along), 1.5));
	float streak = smoothstep(th, th + 0.1, n);
	float window = smoothstep(eaten - 0.03, eaten + 0.1, along) * (1.0 - smoothstep(grow - 0.1, grow + 0.02, along)) * smoothstep(0.015, 0.09, along);
	float v = (0.07 * rim + streak * (0.12 + 0.3 * rim)) * window * power;
	ALBEDO = tint * v;
	ALPHA = 1.0;
}
