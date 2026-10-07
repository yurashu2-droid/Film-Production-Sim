shader_type spatial;
// ボクセル（立方体）の粒。色は MultiMesh の色、光る強さは custom の x。
// 影と陰は本物（まわりの光を受ける）。ドット絵の色のまま、立体として照らされる。
render_mode shadows_disabled;

varying float glow;

void vertex() {
	glow = INSTANCE_CUSTOM.x;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
