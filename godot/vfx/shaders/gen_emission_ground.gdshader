shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D cracks:filter_linear_mipmap;
uniform float phase=0.0;
uniform float layer=0.0;
void fragment(){
 float value=texture(cracks,UV).r;
 float r=length((UV-.5)*2.0);
 float crack=smoothstep(layer<.5?.13:.38,.92,value);
 float front=smoothstep(.0,.2,phase-r*.25);
 float supply=1.0-smoothstep(3.8+r*.65,4.2+r*.65,phase);
 // Heat drains outward after the final jet. A separate dark deposit settles, then dries.
 float deposit=smoothstep(1.1,2.8,phase)*(1.0-smoothstep(4.8+r*.4,5.3+r*.4,phase));
 vec3 color=layer<.5?mix(vec3(.20,.06,.015),vec3(.035,.023,.022),1.0-supply):vec3(1.3,.37,.045);
 ALBEDO=color;
 EMISSION=layer<.5?vec3(0.0):color*supply*.6;
 ALPHA=crack*front*(layer<.5?max(supply*.42,deposit*.5):supply*.78);
}
