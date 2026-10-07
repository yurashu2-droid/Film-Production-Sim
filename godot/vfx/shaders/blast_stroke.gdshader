shader_type spatial;
// 先端が尖り、根元が裂ける炎の筋。白い芯・黄・橙をぼかさず塗り分ける。
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform float width = 0.3;
uniform float remaining = 1.0;
uniform bool shock = false;
void vertex() {
 vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
 vec3 t = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
 vec3 side = cross(t, normalize(p));
 side = dot(side, side) > 0.00001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
 float shape = shock ? 1.0 : pow(UV.x, 0.6) * (1.0 - UV.x) * 3.0;
 VERTEX = p + side * (UV.y - 0.5) * width * shape * remaining;
 NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
 float edge = abs(UV.y - 0.5) * 2.0;
 float jag = 0.78 + 0.15 * sin(UV.x * 43.0) + 0.07 * sin(UV.x * 91.0);
 if (edge > jag || remaining < 0.02) { discard; }
 ALBEDO = shock ? vec3(2.0, 0.65, 0.12) : (edge < 0.21 ? vec3(8.0, 6.0, 1.1) : (edge < 0.56 ? vec3(5.0, 2.3, 0.06) : vec3(3.0, 0.35, 0.025)));
}
