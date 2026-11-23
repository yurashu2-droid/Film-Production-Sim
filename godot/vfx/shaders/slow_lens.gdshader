// スロー光線：浴びている物・人の「像」を、蜃気楼のようにゆがめる（カメラを向く板で、画面の絵をずらして描き直す）。
// 考え方：光線の中は、光も遅い。物の真ん中の像はすぐ届くが、外側の像は遅れて届く。
//   lag    ：物のいまの場所 − 遅れて追う場所（ワールド）。外側ほど、この分だけ像が遅れて見える（真ん中は遅れない）
//   shimmer：蜃気楼のゆらぎ（横に長い帯ごとに、像が左右にゆれ、上下に少し伸び縮みする。ゆっくり）
//   gain   ：全体の強さ（出入りで 0〜1）
//   haze   ：ほんのり紫のもや（うすい煙が、ゆっくり昇る。線や光は足さない）
// 板のふちでは、ずらす量ともやを 0 にして、まわりの絵とつなぐ
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 lag = vec3(0.0);
uniform float gain = 1.0;
uniform float shimmer = 1.0;
uniform float t = 0.0;
uniform float seed = 0.0;
uniform float haze = 1.0;
uniform vec3 haze_tint = vec3(0.62, 0.44, 1.0);

varying vec2 lag_uv;

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
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 centre = VIEW_MATRIX * vec4((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz, 1.0);
	// 遅れの向きと長さを、画面の上の向きと長さに直す
	vec4 here = PROJECTION_MATRIX * centre;
	vec4 there = PROJECTION_MATRIX * (centre + VIEW_MATRIX * vec4(lag, 0.0));
	lag_uv = (there.xy / there.w - here.xy / here.w) * 0.5;
	centre.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * centre;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r >= 1.0) {
		discard;
	}
	float hold = 1.0 - smoothstep(0.72, 1.0, r);          // 板のふちでは、ずらさない
	float outer = smoothstep(0.08, 0.6, r) * hold;        // 真ん中は遅れず、外ほど遅れる
	// 蜃気楼：横に長い帯（大きく遅い）と、細かい帯（小さく速い）
	float band = vn(vec2(seed * 7.0, p.y * 4.5 - t * 0.32)) - 0.5;
	float fine = vn(vec2(p.x * 1.5 + seed * 3.0, p.y * 12.0 + t * 0.55)) - 0.5;
	vec2 wave = vec2(band * 0.012 + fine * 0.004, fine * 0.006) * shimmer * hold;
	vec2 uv = SCREEN_UV + (lag_uv * outer + wave) * gain;
	vec3 col = texture(screen_tex, uv).rgb;
	// ほんのり紫：全体をうすく染め、その上に、ゆっくり昇るもや（大きい塊は遅く、小さい塊は少し速く）
	float soft = 1.0 - smoothstep(0.5, 1.0, r);
	float puff = vn(p * 1.5 + vec2(seed * 5.0, t * 0.11)) * 0.62 + vn(p * 3.3 + vec2(seed * 9.0 - t * 0.04, t * 0.2)) * 0.38;
	float smoke = smoothstep(0.36, 0.74, puff) * soft;
	float amount = (0.14 * soft + 0.46 * smoke) * haze * gain;
	col = mix(col, col * mix(vec3(1.0), haze_tint, 0.7) + haze_tint * 0.2, amount);
	ALBEDO = col;
	ALPHA = 1.0;
}
