shader_type spatial;
// 白黒の絵を「型」にして塗る板（ひび割れ・コミックの衝撃マーク・渦）。明るさをしきい値で切って、ふちをくっきりさせる。
// reveal で中心から外へ現れ、hide で外から中心へ消える。spin で絵を回す。sweep で扇形にぬぐう。
// cut を上げていくと、絵の細い所から千切れて消える（縮めて消すより「ほどける」ように見える）。
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D shape : filter_linear_mipmap, repeat_disable;
uniform vec4 color = vec4(1.0);
uniform vec4 core_color = vec4(1.0);      // 絵の明るい所（中心）に使う色
uniform float cut = 0.3;                   // これより暗い所は描かない
uniform float core_cut = 0.8;
uniform float reveal = 1.0;                // 0〜1。中心からこの半径まで描く
uniform float hide = 0.0;                  // 0〜1。外側からこの割合を消す
uniform float spin = 0.0;
uniform float sweep = 0.0;                 // 0〜1。中心のまわりを一周、扇形にぬぐって消す
uniform float sweep_from = 0.0;
uniform bool billboard = false;
uniform float toward_camera = 0.0;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		float away = max(-MODELVIEW_MATRIX[3].z, 0.01);
		float near = clamp((away - toward_camera) / away, 0.1, 1.0);
		MODELVIEW_MATRIX[3].xyz *= near;
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz) * near, 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz) * near, 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float c = cos(spin);
	float s = sin(spin);
	vec2 uv = vec2(p.x * c - p.y * s, p.x * s + p.y * c) + 0.5;
	float v = texture(shape, uv).r;
	float around = fract(atan(p.y, p.x) / 6.2832 + sweep_from);
	if (around < sweep || v < cut || r > reveal * 1.05 || r > 1.0 - hide || uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;
	}
	vec4 col = mix(color, core_color, step(core_cut, v));
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
