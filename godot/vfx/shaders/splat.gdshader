shader_type spatial;
// 地面のインク（スプラトゥーン風）。平たい色面にせず、厚みと艶を描く。
//   形    丸い本体から、細長い腕が数本だけ放射状に伸びる。腕の先や外側に、ちぎれた滴
//   厚み  ふちから内側へ盛り上がる高さを作り、光の当たる側のふちを白く、反対側を暗くする
//   艶    内側に、ゆるい照りの面と、小さく鋭い白い点
//   spread 0〜1 で広がる ／ recede 0〜1 で乾く（ふちから不揃いに食われ、島に分かれて消える。円のまま縮めない）
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform vec3 color = vec3(1.0, 0.32, 0.03);
uniform float spread = 1.0;
uniform float recede = 0.0;
uniform vec2 seed = vec2(0.0);
uniform float arm = 1.0;            // 腕の伸び具合。小さな滴の跡は 0.3 くらいにして丸く保つ（全部が星形になるのを防ぐ）

// ふちからの内側への距離（正なら中）。腕は角度の鋭い山で作る
float inside(vec2 uv) {
	vec2 p = uv - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	float n = texture(noise_texture, uv * 0.35 + seed).r;
	float arms = pow(abs(sin(a * 2.5 + seed.x * 6.28)), 6.0) * (0.5 + n);
	float thin = pow(abs(sin(a * 5.5 + seed.y * 6.28)), 12.0);
	float edge = spread * (0.5 + arm * (0.28 * arms + 0.14 * thin) + 0.1 * n);
	return edge - r;
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float d = inside(UV);
	// ちぎれた滴：本体の外の、ノイズの高い所
	float dots = texture(noise_texture, UV * 0.9 + seed * 2.0).r;
	float blob = (dots - 0.78) * 0.5;
	bool drop = d < 0.0 && blob > 0.0 && r < spread;
	float depth = drop ? blob : d;
	// 乾く：ふちから不揃いに食う
	float eat = texture(noise_texture, UV * 1.4 + seed * 4.0).r;
	if (depth < recede * (0.05 + 0.6 * eat) || (depth < 0.0)) {
		discard;
	}
	// 厚み：ふちの近くで盛り上がる高さ。画面上の傾きから、光の当たる側と影の側を決める
	float h = smoothstep(0.0, 0.07, depth - recede * (0.05 + 0.6 * eat));
	vec2 slope = vec2(dFdx(h), dFdy(h));
	float facing = dot(normalize(slope + vec2(0.00001)), normalize(vec2(-0.45, -0.9))) * step(0.0005, length(slope));
	vec3 col = color * mix(0.86, 1.08, smoothstep(0.0, 0.3, depth));
	col = facing < -0.35 ? color * 0.55 : col;               // 影の側のふち
	col = facing > 0.45 ? color * 0.5 + vec3(0.95) : col;     // 光の側のふち
	// 艶：ゆるい照りの面と、鋭い白い点
	float sheen = texture(noise_texture, UV * 0.6 + seed * 3.0 + vec2(0.37)).r;
	col = (sheen > 0.66 && h > 0.99) ? color * 1.12 + vec3(0.12) : col;
	col = (sheen > 0.84 && h > 0.99) ? vec3(1.75) : col;
	ALBEDO = col;
}
