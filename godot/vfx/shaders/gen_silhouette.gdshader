shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float clock = 0.0;
uniform float layer = 0.0;
uniform float phase = 0.0;
varying float local_width;
void vertex() {
	float y = UV.y;
	float lag = y * 0.48 + layer * 0.08;
	float t = clock - lag;
	float radial = mix(1.0, 0.48, layer / 2.0);
	float wave = sin(y * 8.3 - t * 4.0 + phase);
	// Two finite pressure releases advance through the generated contour.
	// Their bellies move upward; the earlier neck narrows behind each release.
	float first = exp(-pow((y - (t - 0.18) * 0.62) * 4.7, 2.0));
	float second_pressure = exp(-pow((y - (t - 1.20) * 0.65) * 4.2, 2.0));
	float shoulder = max(first, second_pressure);
	float width = radial * (0.48 + wave * 0.13 + first * 0.76 + second_pressure * 0.87);
	float center = (COLOR.r - 0.5) * 3.65;
	VERTEX.x = center * radial + (VERTEX.x - center) * width;
	VERTEX.z *= radial;
	float swirl = y * (sin(y * 2.1 - t * 1.1) * 0.38 + (layer - 1.0) * 0.44);
	VERTEX.xz = mat2(vec2(cos(swirl), sin(swirl)), vec2(-sin(swirl), cos(swirl))) * VERTEX.xz;
	VERTEX.x += (sin(y * 5.0 - t * 2.5) * 0.44 + sin(t * 1.8 + y * 2.0) * 0.32) * y;
	VERTEX.x += (first - second_pressure) * 0.50 * y;
	VERTEX.z += sin(y * 5.3 - t * 2.0 + phase) * 0.33 * y;
	float turn = smoothstep(1.2, 2.5, clock) * (1.0 - smoothstep(3.2, 4.5, clock));
	VERTEX.x += turn * sin(y * 3.2) * y * 1.1;
	VERTEX.y += sin(y * 4.8 - t * 3.0) * 0.28 * y;
	float escape = max(clock - (3.2 + layer * 0.19), 0.0);
	VERTEX.y += escape * (0.55 + layer * 0.12);
	VERTEX.x += escape * (0.19 - layer * 0.10) * y;
	local_width = shoulder;
}
void fragment() {
	float y = UV.y;
	float start = 0.14 + layer * 0.11;
	float head = smoothstep(start, 1.45 + layer * 0.1, clock);
	float tail = max(0.0, (clock - (3.12 + layer * 0.24)) * (0.85 + layer * 0.035));
	float window = smoothstep(tail - 0.09, tail + 0.05, y) * (1.0 - smoothstep(head - 0.09, head, y));
	float lane = sin(UV.x * 18.8496 + y * 9.0 - clock * (2.7 + layer * 0.4) + phase);
	float second = sin(UV.x * 31.4159 - y * 6.0 + clock * 2.3 + phase);
	// Permanent advected sparse lanes; no random lifetime holes.
	float density = smoothstep(-0.05 - layer * 0.18, 0.31 - layer * 0.08, lane + second * 0.32);
	float hot = smoothstep(0.2, 0.85, lane) * (0.45 + local_width * 0.55);
	vec3 cold = layer < 0.5 ? vec3(0.46, 0.024, 0.005) : (layer < 1.5 ? vec3(1.3, 0.12, 0.008) : vec3(2.0, 0.85, 0.20));
	vec3 bright = layer < 0.5 ? vec3(1.1, 0.12, 0.012) : (layer < 1.5 ? vec3(2.6, 0.72, 0.08) : vec3(3.6, 2.5, 1.4));
	float cooling = smoothstep(3.55 + layer * 0.18, 4.6 + layer * 0.16, clock);
	vec3 color = mix(cold, bright, hot) * (1.0 - cooling * 0.63);
	// The last transported tip becomes a dull ember, not an isolated white dot.
	color = mix(color, vec3(0.30, 0.039, 0.006), cooling);
	ALBEDO = color;
	EMISSION = color * (0.35 + layer * 0.24);
	ALPHA = density * window * (layer < 0.5 ? 0.47 : (layer < 1.5 ? 0.63 : 0.78));
	if (ALPHA < 0.025) discard;
}
