shader_type spatial;
// 超能力：透視で見えた物の影（vfx/esper/esper_sight.gd）。壁の向こうの物と同じメッシュを、奥行きを無視して平たい色で描く。
// 見えるのは「透視の窓」（壁の上の円。lens_center・lens_radius・lens_squash）を通して見える所だけ：
// カメラからその点への視線が、壁の面（z = wall_z）を窓の中で横切る時だけ描く。
render_mode unshaded, depth_test_disabled, depth_draw_never, shadows_disabled, cull_back;

uniform vec3 color = vec3(1.0, 0.45, 0.75);
uniform vec3 color_edge = vec3(1.35, 1.2, 1.3);
uniform float opacity = 0.9;
uniform float phase = 0.0;
uniform float wall_z = 0.3;
uniform vec2 lens_center = vec2(0.0, 1.0);
uniform float lens_radius = 0.0;
uniform float lens_squash = 1.0;        // 窓の縦のつぶれ（1＝円、0＝閉じた目）

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	float k = (wall_z - eye.z) / (world.z - eye.z);
	vec2 on_wall = mix(eye.xy, world.xy, k) - lens_center;
	on_wall.y /= max(lens_squash, 0.001);
	if (length(on_wall) > lens_radius) {
		discard;
	}
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	// 細い横じま（映りの悪い画面のように、コマごとに流れる）
	float scan = step(0.5, fract(world.y * 26.0 - phase));
	ALBEDO = mix(color * (0.82 + 0.18 * scan), color_edge, rim);
	ALPHA = opacity;
}
