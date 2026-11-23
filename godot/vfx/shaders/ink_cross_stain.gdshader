shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float spread = 1.0;
uniform float wick = 0.0;
uniform float seed = 0.0;
// Four irregular lobes wick along oblique capillaries, never a shrinking circle.
void fragment() {
 vec2 p=UV*2.0-1.0;
 float angle=atan(p.y,p.x);
 float edge=.58+.12*sin(angle*3.0+seed)+.08*sin(angle*7.0-seed*2.0);
 float reach=length(p)/max(spread,.001);
 float channel=sin(p.x*17.0+p.y*8.0+seed)*.5+.5;
 float absorbed=wick*(.75+.35*channel+.16*p.x);
 if(reach>edge || absorbed>1.0-reach*.36) discard;
 ALBEDO=vec3(.025,.022,.024)+vec3(.05)*smoothstep(.0,.035,edge-reach)*(1.0-wick)*.3;
}
