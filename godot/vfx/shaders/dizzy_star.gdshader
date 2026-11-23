// のびた人の頭の上を回る星（vfx_dizzy_stars.gd）。紙を切り抜いたような星：濃い茶のふち、中は黄色の2段。光らせない。
// カメラを向く板に描く。spin で、板の中の星を回す。半透明は使わない（形の外は捨てる）
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float spin = 0.0;
uniform vec3 fill = vec3(1.0, 0.85, 0.3);
uniform vec3 shade = vec3(0.94, 0.63, 0.17);
uniform vec3 ink = vec3(0.27, 0.16, 0.07);

// 5つの角を持つ星までの距離（中が負）。r：角の先まで／rf：くびれの深さ
float star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 centre = VIEW_MATRIX * (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0));
	centre.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * centre;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	q.y = -q.y;
	float c = cos(spin);
	float s = sin(spin);
	vec2 p = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	float d = star(p, 0.74, 0.52) - 0.12;          // 角を丸める（ぬいぐるみの絵柄に合わせる）
	if (d > 0.0) {
		discard;
	}
	// 明るい側は左上（板の向きで決める。星が回っても、明るい側は動かない）
	vec3 col = (q.y - q.x * 0.5) > -0.18 ? fill : shade;
	ALBEDO = d > -0.13 ? ink : col;
}
