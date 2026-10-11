shader_type spatial;
// comic_impact の不透明な暖色面＋暗い茶の輪郭を、age駆動の肩と供給カットへ拡張。
render_mode unshaded, cull_disabled, shadows_disabled;
uniform int kind = 0;
uniform vec3 tint = vec3(1.0, 0.78, 0.24);
uniform vec3 ink = vec3(0.17, 0.060, 0.018);
uniform float clock = 0.0;
uniform float phase = 0.0;
uniform float lean = 0.0;
uniform float eaten = -1.1;

float burst_edge(vec2 p, float count, float inset, float outer, float offset) {
	float angle = mod(atan(p.y, p.x) + offset + 6.283185, 6.283185);
	float step_angle = 6.283185 / (count * 2.0);
	float sector = floor(angle / step_angle);
	float a0 = sector * step_angle;
	float a1 = a0 + step_angle;
	float r0 = mod(sector, 2.0) < 0.5 ? outer * (0.91 + 0.11 * sin(a0 * 3.0 + 0.5) + 0.07 * cos(a0 * 5.0)) : inset;
	float r1 = mod(sector + 1.0, 2.0) < 0.5 ? outer * (0.91 + 0.11 * sin(a1 * 3.0 + 0.5) + 0.07 * cos(a1 * 5.0)) : inset;
	r0 += lean * 0.03 * sin(a0 * 2.0 - clock * 13.0);
	r1 += lean * 0.03 * sin(a1 * 2.0 - clock * 13.0);
	float radius = r0 * r1 * sin(step_angle) / max(r1 * sin(a1 - angle) + r0 * sin(angle - a0), 0.001);
	return radius - length(p);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX *= mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	p.x -= 0.25 * lean * p.y;
	float edge;
	if (kind == 0) {
		// 前肩は圧力を受けて開き、後部は首が細くなる。全体scaleの星にしない。
		vec2 flowing = p;
		flowing.x *= mix(1.0, p.x > 0.0 ? 0.86 : 1.46, lean);
		flowing.y += lean * 0.16 * (p.x * p.x - 0.15);
		flowing.y *= 1.03 + 0.23 * lean * max(-p.x, 0.0);
		edge = burst_edge(flowing, 7.0, 0.43 - 0.07 * lean, 0.94 - 0.06 * lean, phase + lean * 0.27);
	} else if (kind == 3) {
		edge = burst_edge(p * vec2(1.0, 1.15), 3.0, 0.34, 0.83, phase + lean * 0.40);
	} else if (kind == 1) {
		float center = -0.10 + 0.18 * p.x * p.x;
		float width = 0.18 * (1.0 - smoothstep(0.4, 0.95, abs(p.x)));
		edge = min(width - abs(p.y - center), 0.95 - abs(p.x));
	} else {
		p = mat2(vec2(cos(phase + lean), -sin(phase + lean)), vec2(sin(phase + lean), cos(phase + lean))) * p;
		float width = 0.34 * (1.0 - smoothstep(-0.55, 0.84, p.x));
		edge = min(width - abs(p.y - 0.22 * p.x * p.x), min(p.x + 0.72, 0.88 - p.x));
	}
	float cut = (UV.x * 2.0 - 1.0) - eaten;
	edge = min(edge, cut);
	if (edge < 0.0) discard;
	vec3 paint = tint;
	if (kind == 0) paint = mix(tint * vec3(1.0, 0.86, 0.66), tint, smoothstep(-0.45, 0.32, p.y + 0.2 * p.x));
	ALBEDO = mix(ink, paint, smoothstep(0.047, 0.078, edge));
}
