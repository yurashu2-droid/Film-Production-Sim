shader_type spatial;
// 火花・光る芯。粒子の色をそのまま強く出す。
render_mode unshaded, shadows_disabled;

uniform vec3 tint = vec3(1.0);

void fragment() {
	ALBEDO = COLOR.rgb * tint;
}
