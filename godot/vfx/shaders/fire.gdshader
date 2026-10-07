shader_type spatial;
// 様式化した炎（チュートリアル「Stylized Fire」の組み立て）。
// 3階調の炎の絵に色を掛け、上へ流れる歪み画像でUVを揺らす。根元はマスクで揺らさない。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D flame_texture : repeat_disable, filter_linear_mipmap;
uniform sampler2D distortion_texture : repeat_enable, filter_linear;
uniform vec4 color = vec4(4.0, 0.8, 0.0, 1.0);   // 1を超える値でグローに乗る
uniform vec3 core_boost = vec3(4.0, 3.2, 1.2);   // 芯に足す明るさ
uniform vec2 speed = vec2(0.0, 1.0);             // 歪みの流れる速さ
uniform float distortion = 0.25;                 // 歪みの強さ
uniform vec2 distortion_scale = vec2(1.0, 0.7);
uniform float mask_start = 0.05;                 // この高さまでは歪ませない
uniform float mask_end = 0.6;
uniform float phase = 0.0;

void vertex() {
	// 縦軸だけカメラを向く（Yビルボード）。大きさは保つ。
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float mask = smoothstep(mask_start, mask_end, 1.0 - UV.y);
	float d = texture(distortion_texture, UV * distortion_scale + speed * TIME + vec2(phase)).r;
	vec2 uv = UV + (d - 0.5) * distortion * mask;
	float f = texture(flame_texture, uv).r;
	// 絵の3階調（0.5 / 0.75 / 1.0）を、揺らした後でくっきり出し直す
	float outer = smoothstep(0.22, 0.30, f);
	float mid = smoothstep(0.58, 0.66, f);
	float core = smoothstep(0.84, 0.92, f);
	ALBEDO = color.rgb * (0.5 * outer + 0.25 * mid + 0.25 * core) + core_boost * core;
	ALPHA = outer * mix(0.8, 1.0, mid) * color.a * COLOR.a;
}
