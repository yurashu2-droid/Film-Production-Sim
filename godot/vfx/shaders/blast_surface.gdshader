shader_type spatial;
// 参考画像の白熱した傘と、下端から食い上がる黄・橙の炎。TIMEを使わずコマ送りに従う。
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform float phase = 0.0;
uniform float heat = 1.0;
uniform float remaining = 1.0;
uniform bool stem = false;
uniform float flame_rise = 0.25;
varying vec3 normal_world;
void vertex() {
 if (!stem) {
  float angle = atan(VERTEX.z, VERTEX.x);
  VERTEX.xz *= 1.0 + 0.04 * sin(angle * 7.0 + UV.y * 9.0 - phase * 6.0);
  VERTEX.y += 0.035 * sin(angle * 9.0 - phase * 7.0) * sin(UV.y * 3.14159);
 }
 normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 float n = texture(noise_texture, UV * vec2(5.0, 2.0) + vec2(0.0, -phase * 0.7)).r;
 float cells = texture(noise_texture, UV * vec2(8.0, 4.0) + vec2(0.23, phase * 0.1)).r;
 if (remaining < 0.99 && cells * 0.85 + 0.15 < 1.0 - remaining) { discard; }
 float tongues = texture(noise_texture, UV * vec2(17.0, 1.1) + vec2(0.0, -phase * 0.6)).r;
 float boundary = flame_rise + 0.13 * sin(UV.x * 57.0 + phase * 2.0) + tongues * 0.32;
 float stripe = stem ? n + 0.16 * sin(UV.x * 31.0 + UV.y * 8.0) : UV.y - boundary;
 vec3 hot = stripe > 0.12 ? vec3(9.0, 7.5, 3.8) : (stripe > -0.07 ? vec3(6.0, 3.3, 0.12) : vec3(3.8, 0.5, 0.045));
 if (stem) { hot = stripe > 0.49 ? vec3(6.0, 2.5, 0.1) : vec3(1.1, 0.13, 0.035); }
 float lit = dot(normalize(normal_world), normalize(vec3(-0.4, 0.8, 0.5)));
 vec3 soot = lit > 0.5 ? vec3(0.42, 0.32, 0.26) : (lit > -0.15 ? vec3(0.24, 0.16, 0.13) : vec3(0.075, 0.048, 0.04));
 ALBEDO = mix(soot, hot * (lit > -0.25 ? 1.0 : 0.67), heat);
}
