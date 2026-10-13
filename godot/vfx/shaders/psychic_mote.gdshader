shader_type spatial;
// 念力の「気のかたまり」：手もとと、物をつかんだ点に置く小さな板（vfx_psychic.gd）。
// 真円にしない。ふちの半径を角度ごとに変え、コマごとに形を描き替える（phase をコマ打ちで渡す）。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 color = vec3(0.7, 0.5, 1.2);
uniform vec3 color_core = vec3(1.4, 1.35, 1.55);
uniform float opacity = 1.0;
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform float ragged = 0.42;      // ふちのでこぼこの深さ

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float around = atan(p.y, p.x) / 6.28318;
	float n = texture(noise_tex, vec2(around * 2.0 + seed, phase * 0.37 + seed * 0.5)).r;
	float rim = 0.95 - ragged * (1.0 - n);
	if (r > rim) {
		discard;
	}
	ALBEDO = mix(color_core, color, smoothstep(0.3, 0.75, r / rim));
	ALPHA = opacity;
}
