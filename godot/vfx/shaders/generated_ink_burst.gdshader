shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
uniform sampler2D image:filter_linear,repeat_disable;
uniform float local_age=-1.0;
uniform float layer=0.0;
void fragment(){
	if(local_age<0.0 || local_age>=1.334){discard;}
	float frame=min(floor(local_age*12.0),15.0);
	vec2 tile=vec2(mod(frame,4.0),floor(frame/4.0));
	// Every cell has a half-texel inset: generated shoulders touch cell edges.
	vec2 uv=(tile+clamp(UV,vec2(.0015625),vec2(.9984375)))/4.0;
	vec4 c=texture(image,uv);
	float gold=step(c.b*1.35,c.r)*step(.20,c.r);
	vec3 color=mix(c.rgb*.30,c.rgb*.86,gold);
	ALBEDO=color;
	EMISSION=color*gold*.55;
	ALPHA=c.a*(.58-layer*.07);
}
