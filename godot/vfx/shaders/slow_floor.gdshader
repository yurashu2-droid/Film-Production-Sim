// スロー光線：届く範囲を、床に映す（上から見た扇形。制作班にだけ見える層に置く）。
// 両わきの線（先へゆっくり送られる破線）と、内側のうすい塗り、先へゆっくり進む弧。先へ行くほどまばらになって、端の手前で無くなる。
//   grow：0→1 で、根元から先へ伸びる／eaten：0→1 で、根元から先へ消える／power：明るさ
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 from = vec3(0.0);
uniform vec3 dir = vec3(0.0, 0.0, 1.0);
uniform float reach = 9.0;
uniform float spread = 0.176;         // 広がりの tan
uniform float grow = 1.0;
uniform float eaten = 0.0;
uniform float power = 1.0;
uniform float t = 0.0;
uniform vec3 tint = vec3(0.42, 0.3, 0.86);
uniform vec3 ink = vec3(0.22, 0.14, 0.42);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = wp.xz - from.xz;
	float flat_len = max(length(dir.xz), 0.2);       // 上や下へ向けるほど、床の上では短くなる
	vec2 a = dir.xz / max(length(dir.xz), 0.0001);
	float s = dot(d, a);
	float perp = abs(d.x * a.y - d.y * a.x);
	float w = s / flat_len * spread;
	float r = length(d) / (reach * flat_len);
	float inside = step(0.0, s) * step(perp, w) * step(r, 1.0);
	// 両わきの線：破線が、先へゆっくり送られる。先へ行くほど、切れ目が長くなる
	float edge = inside * (1.0 - smoothstep(0.035, 0.075, w - perp));
	float gap = mix(0.3, 0.72, smoothstep(0.45, 1.0, r));
	float dash = step(gap, fract(s * 1.5 - t * 0.22));
	// 内側：先へゆっくり進む弧（時間の波）。先では無くなる
	float wave = fract(length(d) * 0.75 - t * 0.2);
	float arc = inside * smoothstep(0.0, 0.05, wave) * (1.0 - smoothstep(0.05, 0.13, wave)) * (1.0 - smoothstep(0.5, 0.95, r));
	float window = smoothstep(eaten - 0.02, eaten + 0.08, r) * (1.0 - smoothstep(grow - 0.08, grow + 0.02, r)) * smoothstep(0.02, 0.08, r);
	float fill = inside * 0.17 * (1.0 - smoothstep(0.6, 1.0, r));
	float line = max(edge * dash, arc * 0.7);
	ALBEDO = mix(tint, ink, line * 0.6);
	ALPHA = clamp(fill + line * 0.8, 0.0, 0.9) * window * power;
}
