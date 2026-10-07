shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float heat = 1.0;
uniform float phase = 0.0;
uniform float curl = 0.0;
uniform float opacity = 1.0;
varying vec3 wn;
void vertex(){
 float angle = curl * (VERTEX.y + 0.7) * 1.8;
 VERTEX.xy = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle))) * VERTEX.xy;
 VERTEX.x += curl * 0.15 * sin(VERTEX.y*3.0);
 wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment(){
 float lit = dot(normalize(wn),normalize(vec3(-0.4,0.8,0.5)));
 vec3 soot = lit > 0.5 ? vec3(0.44,0.42,0.39) : (lit > -0.15 ? vec3(0.27,0.25,0.23) : vec3(0.10,0.09,0.08));
 float stripe = UV.y - 0.25 - 0.13*sin(UV.x*57.0+phase*2.0);
 vec3 hot = stripe > 0.12 ? vec3(9,7.5,3.8) : (stripe > -0.07 ? vec3(6,3.3,0.12) : vec3(3.8,0.5,0.045));
 ALPHA = opacity;
 ALBEDO = mix(soot,hot*(lit > -0.25 ? 1.0 : 0.67),heat);
}
