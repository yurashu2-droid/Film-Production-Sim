shader_type spatial;
// 水の玉・泡・しずく。縁が明るく、中は濃い青。表面は少し揺れる。光らせず、塗りの段で見せる（トゥーン）。
// 縁の明るい所はしきい値で切って一本の線にし、グローには乗せない。
render_mode unshaded, cull_back;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec3 body = vec3(0.12, 0.45, 1.0);
uniform vec3 deep = vec3(0.04, 0.16, 0.5);
uniform vec3 rim = vec3(0.72, 0.95, 1.0);
uniform vec3 glint = vec3(1.0, 1.0, 1.0);
uniform float wobble = 0.0;     // 表面の揺れ（半径に対する割合）
uniform float phase = 0.0;

void vertex() {
	float w = sin(UV.x * 6.2832 * 2.0 + phase * 3.0) * 0.5 + sin(UV.y * 6.2832 * 3.0 - phase * 2.3) * 0.5;
	VERTEX += NORMAL * w * wobble;
}

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = 1.0 - ndv;
	vec3 col = mix(body, deep, smoothstep(0.35, 0.8, edge) * 0.6);
	col = mix(col, rim, step(0.72, edge));
	// 中を流れる筋（水の動き）
	float n = texture(noise_texture, UV * 1.5 + vec2(phase * 0.04, phase * 0.02)).r;
	col = mix(col, rim, step(0.8, n) * 0.25 * (1.0 - edge));
	// 左上からの白いハイライト
	float spot = pow(max(dot(normalize(NORMAL), normalize(vec3(-0.45, 0.6, 0.66))), 0.0), 14.0);
	col = mix(col, glint, step(0.82, spot));
	ALBEDO = col;
}
