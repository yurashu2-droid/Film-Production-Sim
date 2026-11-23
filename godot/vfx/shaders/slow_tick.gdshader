// スロー光線：浴びている物・人のまわりの「時計の目盛り」（カメラを向く板に描く）。
// 12本の目盛り（3本おきに長い）と、縁を回る針。光らせない（淡い色＋暗い輪郭線。明るい背景でも暗い背景でも読める）。
//   appear：0→1 で、上から時計回りに目盛りが1本ずつ現れる
//   wipe  ：0→1 で、上から時計回りに目盛りがぬぐわれる（針が早回りして、通った所から消える）
//   hand  ：針の向き（1 で1周。コマ送りで進める）
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform float appear = 1.0;
uniform float wipe = 0.0;
uniform float wipe_from = 0.0;
uniform float hand = 0.0;
uniform float seed = 0.0;
uniform vec3 light = vec3(1.0, 0.97, 0.88);
uniform vec3 ink = vec3(0.2, 0.14, 0.34);
uniform vec3 hand_ink = vec3(0.46, 0.2, 0.78);

float ih(uint n) {
	n = (n ^ 61u) ^ (n >> 16u);
	n *= 9u;
	n = n ^ (n >> 4u);
	n *= 0x27d4eb2du;
	n = n ^ (n >> 15u);
	return float(n & 0xffffu) / 65535.0;
}

void vertex() {
	// カメラを向く（大きさは保つ）
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 centre = VIEW_MATRIX * vec4((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz, 1.0);
	centre.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * centre;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float a = fract(atan(p.x, p.y) / TAU + 1.0);          // 上が 0、時計回り
	float k = mod(floor(a * 12.0 + 0.5), 12.0);
	float ta = k / 12.0;
	float rnd = ih(uint(k) + uint(seed * 97.0) * 131u);
	bool major = mod(k, 3.0) < 0.5;
	// 目盛りは、長さ・太さ・位置を不揃いに、両端を細らせる
	float r0 = major ? 0.52 + 0.05 * rnd : 0.7 + 0.06 * rnd;
	float r1 = 0.96 - 0.03 * rnd;
	float w = (major ? 0.04 : 0.026) * (0.85 + 0.3 * rnd);
	float da = abs(fract(a - ta + 0.5) - 0.5) * TAU * r;
	float t = clamp((r - r0) / (r1 - r0), 0.0, 1.0);
	float taper = pow(smoothstep(0.0, 0.5, t), 0.6) * (1.0 - 0.25 * smoothstep(0.85, 1.0, t));
	float inside = step(r0, r) * step(r, r1);
	float line = inside * (1.0 - smoothstep(w * taper * 0.75, w * taper, da));
	float outl = step(r0 - 0.035, r) * step(r, r1 + 0.035) * (1.0 - smoothstep(w * taper + 0.022, w * taper + 0.036, da));
	// ぬぐうのは、針のいる所（wipe_from）から時計回りに
	float shown = step(ta + 0.04, appear) * step(wipe, fract(ta - wipe_from + 1.0) + 0.0001);
	// 針：縁を回る、くさび形の太い印（真ん中の物を隠さない）
	float dha = abs(fract(a - fract(hand) + 0.5) - 0.5) * TAU * r;
	float ht = clamp((r - 0.42) / 0.6, 0.0, 1.0);
	float hw = 0.07 * (1.0 - 0.8 * ht);
	float hin = step(0.42, r) * step(r, 1.0);
	float hline = hin * (1.0 - smoothstep(hw * 0.75, hw, dha)) * step(0.45, r) * step(r, 0.985);
	float hout = hin * (1.0 - smoothstep(hw + 0.022, hw + 0.038, dha));
	float hand_on = step(0.03, appear) * (1.0 - step(0.999, wipe));
	float l = line * shown;
	float o = outl * shown;
	float hl = hline * hand_on;
	float ho = hout * hand_on;
	// 針は、濃い紫の芯に白いふち（目盛りは、白い芯に濃いふち）
	vec3 col = mix(ink, light, l);
	col = mix(col, mix(light, hand_ink, hl), ho);
	ALBEDO = col;
	ALPHA = max(max(l, o * 0.9), ho);
}
