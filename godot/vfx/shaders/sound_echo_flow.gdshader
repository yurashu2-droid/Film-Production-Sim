shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec3 color=vec3(.1,.3,.36);
uniform float phase=0.0;
uniform float seed=0.0;
uniform float sparse=.25;
void fragment(){
 // Broad permanent pressure windows show the farther curved sheets.
 float band=sin(UV.x*6.28318 + seed + 1.35*sin(UV.y*8.0-phase*2.1));
 if(band<sparse || UV.y<.025 || UV.y>.975)discard;
 float rim=smoothstep(.78,.98,band);
 ALBEDO=color*(.7+.3*rim);
 ALPHA=smoothstep(sparse,sparse+.18,band)*(.74+.20*rim);
}
