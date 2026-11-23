shader_type spatial;
// 3D の物を、パンクなペン画の塗りで描く。形は立体、塗りは 2D。
//   光の当たる面  べた塗り（fill）
//   影の面        スクリーントーン（画面に貼りついた網点。影が深いほど点が大きい）
//   一番暗い面    墨のべた
// 光の向きはカメラ基準で固定（回り込んでも、絵の影の付き方が変わらない）。光らせない。
// wear：網点が小さくなって消える（トーンがはがれるような終わり方）。
render_mode unshaded, shadows_disabled;

uniform vec3 fill = vec3(0.91, 0.86, 0.85);
uniform vec3 ink = vec3(0.03, 0.03, 0.035);
uniform float tone_scale = 64.0;      // 画面の高さあたりの網点の数
uniform vec3 light_dir = vec3(-0.55, 0.65, 0.5);
uniform float wear = 0.0;
uniform float stripes = 0.0;           // 1 で、黒の斜め縞（警告の縞）を入れる

void fragment() {
	// 画面に貼りついた 45 度の網点
	vec2 sp = FRAGCOORD.xy / VIEWPORT_SIZE.y * tone_scale;
	sp = vec2(sp.x + sp.y, sp.x - sp.y) * 0.7071;
	float dist = length(fract(sp) - 0.5);
	if (dist > 0.72 * (1.0 - wear)) {
		discard;
	}
	float ndl = dot(normalize(NORMAL), normalize(light_dir));
	float shade = clamp((0.55 - ndl) / 0.85, 0.0, 1.0);
	bool dark = shade > 0.92 || dist < 0.5 * sqrt(shade);
	if (stripes > 0.5 && fract(UV.y * 5.0 + UV.x * 3.0) > 0.5) {
		dark = true;
	}
	ALBEDO = dark ? ink : fill;
}
