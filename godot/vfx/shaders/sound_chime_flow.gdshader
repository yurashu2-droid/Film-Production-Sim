shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(0.3, 0.3, 0.5);
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform float sparsity = 0.58;
uniform float shine = 0.3;
void fragment() {
    vec2 q = vec2(UV.x * 2.1 + UV.y * 1.3 + seed, UV.y * 0.4 - phase * 0.55);
    float g = texture(grain, q).r;
    // Sparse moving striations stay fixed in density throughout the release.
    if (g + 0.10 * sin(UV.x * 34.0 + UV.y * 16.0 - phase * 6.0) < sparsity) { discard; }
    ALBEDO = tint;
    EMISSION = tint * shine;
}
