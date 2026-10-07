// Pixel x Real VFX：共通の部品。画像を使わず、ここの計算だけでドット絵を描く。

float px_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float px_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(px_hash(i), px_hash(i + vec2(1.0, 0.0)), f.x), mix(px_hash(i + vec2(0.0, 1.0)), px_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float px_fbm(vec2 p) {
	return px_noise(p) * 0.6 + px_noise(p * 2.03 + 7.1) * 0.3 + px_noise(p * 4.1 + 3.3) * 0.1;
}

// 4x4 の網点（ベイヤー）。マスごとに 0〜1 のしきい値を返す
float px_b2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float px_bayer(vec2 cell) {
	return px_b2(0.5 * cell) * 0.25 + px_b2(cell);
}

// 明るさ 0〜1 を、5色のどれかに決める。色の境目は網点で混ぜる（ドット絵のグラデーション）
vec3 px_ramp(float v, vec2 cell, vec3 c0, vec3 c1, vec3 c2, vec3 c3, vec3 c4) {
	float s = clamp(v, 0.0, 0.999) * 4.0;
	float i = floor(s) + step(px_bayer(cell), fract(s) * 0.85);
	vec3 col = c0;
	col = i > 0.5 ? c1 : col;
	col = i > 1.5 ? c2 : col;
	col = i > 2.5 ? c3 : col;
	col = i > 3.5 ? c4 : col;
	return col;
}
