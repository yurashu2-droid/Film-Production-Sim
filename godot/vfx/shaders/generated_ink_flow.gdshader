shader_type spatial;
render_mode cull_disabled,shadows_disabled,depth_draw_never;
uniform sampler2D image:filter_linear_mipmap,repeat_disable;
uniform sampler2D relief:filter_linear_mipmap,repeat_enable;
uniform sampler2D normal_tex:filter_linear_mipmap,repeat_enable;
uniform sampler2D ao_tex:filter_linear_mipmap,repeat_enable;
uniform sampler2D roughness_tex:filter_linear_mipmap,repeat_enable;
uniform float layer=0.0;
uniform float phase=0.0;
uniform float seed=0.0;
vec2 relief_uv(vec2 uv){return uv*vec2(1.2,1.6)+vec2(seed,phase*.075);}
void vertex(){
	float h=textureLod(relief,relief_uv(UV),1.0).r;
	VERTEX+=NORMAL*(h-.5)*.10;
}
void fragment(){
	vec2 uv=UV;
	uv.x=clamp(uv.x+.045*sin(UV.y*9.0+seed*4.0),.001,.999);
	vec4 c=texture(image,uv);
	float q=COLOR.r;
	float opacity=layer<.5 ? .86 : .63;
	vec3 color=c.rgb*.37;
	if(layer>1.5){
		// Keep the gold's turbulent amber fringe; the baked white ridge reads as a solid wire.
		color=c.rgb*vec3(1.20,.87,.55);
		opacity=.70*(1.0-smoothstep(.58,.96,dot(c.rgb,vec3(.2126,.7152,.0722))));
	}
	if(layer>2.5){
		color=mix(c.rgb,vec3(2.3,1.95,1.5),.7);
		opacity*=exp(-pow((phase-2.04)/.13,2.0));
	}
	float edge=smoothstep(0.0,.055,UV.y)*(1.0-smoothstep(.945,1.0,UV.y));
	float born=smoothstep(0.0,.10,phase-COLOR.g);
	ALBEDO=color;
	vec2 p=relief_uv(UV);
	NORMAL_MAP=texture(normal_tex,p).rgb;
	// Height-field cavity approximation, not a baked 3D AO map.
	AO=texture(ao_tex,p).r;
	ROUGHNESS=layer>1.5 ? texture(roughness_tex,p).r : .76;
	METALLIC=layer>1.5 ? .55 : .0;
	EMISSION=layer>1.5 ? color*.13 : vec3(0.0);
	ALPHA=c.a*opacity*edge*born;
}
