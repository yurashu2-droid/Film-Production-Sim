shader_type spatial;
render_mode cull_disabled;
uniform sampler2D height_map : filter_linear;
uniform sampler2D normal_map : hint_normal, filter_linear;
uniform sampler2D ao_map : filter_linear;
uniform sampler2D rough_map : filter_linear;
uniform float clock = 0.0;
uniform float gilding = 0.0;
void fragment(){
 vec2 uv = vec2(UV.x*1.3-clock*.17,UV.y*1.4+clock*.035);
 float h=texture(height_map,fract(uv)).r;
 vec3 black_oil=vec3(.025,.12,.13);
 vec3 bronze=vec3(.72,.38,.09);
 float veins=smoothstep(.51,.74,h);
 ALBEDO=mix(black_oil,bronze,veins*.8+gilding*.15);
 NORMAL_MAP=texture(normal_map,fract(uv)).rgb;
 NORMAL_MAP_DEPTH=.3;
 AO=texture(ao_map,fract(uv)).r;
 ROUGHNESS=texture(rough_map,fract(uv)).r*.47;
 METALLIC=.48;
 EMISSION=vec3(.18,.065,.009)*pow(veins,4.0)*.7;
}
