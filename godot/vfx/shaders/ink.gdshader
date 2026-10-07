shader_type spatial;
// スプラトゥーン風のインクの塊。光らせず、濃い色・暗いふち・白い映り込みの3つで「ぬるっとした艶」を出す。
render_mode unshaded, shadows_disabled;

uniform vec3 color = vec3(1.0, 0.32, 0.03);
uniform vec3 gloss = vec3(1.7, 1.7, 1.7);
uniform float rim_dark = 0.55;

void fragment() {
	vec3 n = normalize(NORMAL);
	float rim = 1.0 - max(dot(n, normalize(VIEW)), 0.0);
	vec3 col = color * COLOR.rgb * mix(0.82, 1.1, n.y * 0.5 + 0.5);
	col = mix(col, col * rim_dark, smoothstep(0.62, 0.68, rim));
	// 映り込み：左上からの大きい光と、右下の小さい照り返し
	float big = dot(n, normalize(vec3(-0.45, 0.7, 0.55)));
	float small = dot(n, normalize(vec3(0.5, -0.35, 0.8)));
	col = big > 0.9 ? gloss : col;
	col = small > 0.975 ? mix(col, gloss, 0.7) : col;
	ALBEDO = col;
}
