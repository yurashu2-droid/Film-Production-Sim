shader_type spatial;
// 着水→毛細管の広がり→照りが消える→斜めに通過する吸収前線。円を縮めない。
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
uniform float seed = 0.0;
uniform float wet = 0.0;
uniform float dry = 0.0;
void fragment() {
	vec2 p = UV-.5;
	float a = atan(p.y,p.x);
	float edge = .32+.05*sin(a*5.0+seed*6.0)+.045*sin(a*9.0-seed*3.0);
	float spread = .32+.68*smoothstep(0.0,.24,wet);
	if(length(p)>edge*spread) discard;
	float wick = UV.y*.78+UV.x*.22;
	if(wick<dry*1.20-.10) discard;
	vec3 ink = vec3(.028,.023,.032);
	float shine = (1.0-smoothstep(.10,.38,wet))*smoothstep(.20,.23,p.x+p.y);
	ALBEDO = ink+vec3(.30,.22,.12)*shine;
}
