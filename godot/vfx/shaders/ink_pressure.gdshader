shader_type spatial;
// 墨の流路。黒は面積を担い、金は内側の筋、白は接続の瞬きだけ。
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform float layer = 0.0;
uniform float seed = 0.0;
uniform float phase = 0.0;
uniform float emission = 0.105;
uniform float newest = 0.0;
uniform float oldest = 0.0;
uniform float duration = 0.7;
uniform bool hand_mode = false;
uniform bool hand_surface = false;
uniform float transfer = 0.0;
uniform vec3 shade;
uniform vec3 hot;
varying float finger_height;

void vertex() {
	finger_height = COLOR.r;
}

void fragment() {
	float e = mix(newest,oldest,UV.y);
	float q = phase-e;
	vec2 uv = vec2(UV.x*3.0+e*2.2+seed,UV.y*.6-q*2.2);
	float grain_value = texture(grain,uv).r;
	// 固定したノイズ消去ではなく、ねじれて移る筆の筋の間に空隙を残す。
	float streak = sin(UV.x*25.133+e*18.0-q*7.0+seed*3.0)+.32*sin(UV.x*62.83-q*11.0);
	float gap = layer<.5 ? .44 : (layer<1.5 ? .50 : -.05);
	if(hand_mode) gap -= .30;
	if(streak+grain_value*.65<gap) discard;
	if(hand_mode) {
		// 供給が切れた手首側から、残る墨は先へ走る。拳の輪郭を空中に残さない。
		if(UV.y<smoothstep(.24,.33,phase)) discard;
	}
	// 各材料が着弾前面へ届いた後は、同じ位置の墨煙へ移る。
	// 黒い四本の残留流路や飛沫を出し続けず、後続の材料も前へ運んで渡す。
	if(layer<.5 && !hand_surface && q>.265) discard;
	if(q<.015 || q>duration || e>emission) discard;
	// 白芯は着弾後に根元から接続が切れ、先へ流れる短い点灯区間だけ。
	if(layer>1.5 && q>.24) discard;
	float front = smoothstep(.12,.19,q)*(1.0-smoothstep(.20,.31,q));
	float rim = smoothstep(.74,.92,grain_value)*.24;
	float warm = layer<.5 ? rim : min(.9,.25+front*.7+rim);
	ALBEDO = mix(shade,hot,warm);
	ALPHA = 1.0-transfer;
}
