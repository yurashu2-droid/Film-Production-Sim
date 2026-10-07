shader_type spatial;
// 連番アニメの煙（手描きの「丸い煙 → 欠ける → 三日月 → 消える」）をカメラ向きの板に貼る。
// コマは MultiMesh の custom の x に入れる（なければ frame）。絵の濃淡を2段に塗り直し、ふちに輪郭線を足す。
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;
uniform vec2 grid = vec2(4.0, 4.0);
uniform float frame = 0.0;
uniform vec3 light = vec3(1.25, 1.1, 0.86);
uniform vec3 shade = vec3(0.86, 0.67, 0.46);
uniform vec3 ink = vec3(0.25, 0.15, 0.08);
uniform float ink_width = 0.012;       // 1コマの幅に対する線の太さ

varying float at_frame;

void vertex() {
	at_frame = floor(clamp(INSTANCE_CUSTOM.x + frame, 0.0, grid.x * grid.y - 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

vec4 cell(vec2 uv) {
	// コマの外へはみ出した分は透明にする（隣のコマを拾わない）
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	vec2 corner = vec2(mod(at_frame, grid.x), floor(at_frame / grid.x));
	return texture(sheet, (corner + clamp(uv, 0.02, 0.98)) / grid);
}

void fragment() {
	// 板のふちに線の余白を取る
	vec2 uv = (UV - 0.5) * 1.08 + 0.5;
	vec4 c = cell(uv);
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854;
		around = max(around, cell(uv + vec2(cos(a), sin(a)) * ink_width).a);
	}
	if (c.a < 0.5 && around < 0.5) {
		discard;
	}
	float lum = dot(c.rgb, vec3(0.333));
	vec3 col = mix(shade, light, smoothstep(0.46, 0.5, lum)) * COLOR.rgb;
	ALBEDO = c.a < 0.5 ? ink : col;
}
