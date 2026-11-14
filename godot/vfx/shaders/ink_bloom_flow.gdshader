shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform sampler2D soft_grain : filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(0.02);
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform float sparsity = 0.58;
uniform float shine = 0.0;
void fragment() {
    // Grain is permanent advected ink porosity, never a lifetime dissolve.
    vec2 q = vec2(UV.x * 3.2 + UV.y * 0.6 + seed, UV.y * 0.95 - phase * 0.85);
    float g = texture(grain, q).r;
    float b = texture(soft_grain, UV * vec2(2.0, 0.7) + vec2(seed * 1.7, phase * -0.8)).r;
    float filaments = g * 0.7 + b * 0.45;
    float film = smoothstep(sparsity - 0.12, sparsity + 0.10, filaments);
    if (film < 0.025) { discard; }
    ALBEDO = tint;
    EMISSION = tint * shine;
    ALPHA = film * 0.78;
}
