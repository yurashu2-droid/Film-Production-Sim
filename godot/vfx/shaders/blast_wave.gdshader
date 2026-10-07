shader_type spatial;
// 動画の火球を包む太い橙の圧力波。膨張し、輪郭が裂けて消える。
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float remaining = 1.0;
uniform float phase = 0.0;
void vertex() {
 float a = atan(VERTEX.z, VERTEX.x);
 VERTEX.y += sin(a * 5.0 + phase * 3.0) * 0.028;
 VERTEX.xz *= 1.0 + 0.02 * sin(a * 7.0);
}
void fragment() {
 float tear = 0.5 + 0.26 * sin(UV.x * 83.0) + 0.19 * sin(UV.x * 141.0 + UV.y * 7.0);
 if (remaining < 0.99 && tear > remaining) { discard; }
 float rim = pow(abs(sin(UV.y * 6.28318)), 5.0);
 ALBEDO = mix(vec3(4.0, 0.65, 0.04), vec3(6.5, 2.4, 0.18), rim);
}
