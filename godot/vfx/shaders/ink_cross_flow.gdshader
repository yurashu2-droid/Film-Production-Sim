shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
// Permanent longitudinal gaps, not a lifetime noise dissolve. Supply is removed
// in emission-time order in the mesh, and every surviving parcel falls to its stain.
uniform vec3 color = vec3(0.025);
uniform vec3 sheen = vec3(0.12);
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform float density = 0.48;
uniform float impulse = 0.0;
uniform sampler2D grain_texture : filter_linear_mipmap, repeat_enable;
void fragment() {
 float strand = sin(UV.x * 25.1327 + 1.4*sin(UV.y*9.0-phase*1.8+seed)+seed*6.0);
 float grain = sin(UV.y*41.0 - phase*4.0 + UV.x*13.0 + seed);
 float broken=sin(UV.y*19.0 + UV.x*7.0-phase*2.5+seed*4.0);
 float ink=texture(grain_texture,vec2(UV.x*3.0+seed,UV.y*.6-phase*.25)).r;
 if (strand < density + grain*0.12 || broken<-.78 || UV.y<0.01 || UV.y>0.99) discard;
 float glint = smoothstep(0.89,0.99,strand)*smoothstep(0.4,0.85,UV.y);
 ALBEDO = mix(color,sheen,glint*.65);
 ALPHA=smoothstep(density+.12,density+.33,strand)*smoothstep(-.78,-.50,broken)*(.68+.32*ink);
 ALBEDO += vec3(0.75,0.44,0.10)*impulse*glint*exp(-pow((UV.y-.82)/.12,2.0));
}
