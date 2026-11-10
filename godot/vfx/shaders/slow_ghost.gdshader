// スロー光線：浴びている物が通った所に残る「コマの残像」（連続写真のように、少し前の姿が何枚か残る）。
// 薄さは半透明ではなく網点（画面の画素を間引く）。古いコマほど粗くなって抜ける。
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 tint = vec3(0.5, 0.38, 0.82);
uniform float density = 0.5;          // 塗る画素の割合（0〜1）

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	ivec2 cell = ivec2(FRAGCOORD.xy / 3.0) & ivec2(3);
	if ((BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0 >= density) {
		discard;
	}
	ALBEDO = tint;
}
