shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float vapor = 0.0;
void fragment() {
 vec2 p = floor(UV * vec2(22.0, 10.0)) / vec2(22.0, 10.0);
 float edge = pow(max(0.0, sin(p.y * 3.14159)), mix(0.18, 1.2, vapor));
 float body = mix(1.0, .60 + .40 * sin(p.x * 18.0 + p.y * 5.0), vapor);
 vec3 stepped = floor(COLOR.rgb * 6.0 + .5) / 6.0;
 ALBEDO = stepped;
 EMISSION = stepped * mix(.75, .04, vapor);
 ALPHA = COLOR.a * edge * body;
}
