shader_type spatial;
render_mode cull_disabled,shadows_disabled,depth_draw_never;
uniform sampler2D image:filter_linear_mipmap,repeat_disable;
uniform sampler2D relief:filter_linear_mipmap,repeat_enable;
uniform sampler2D normal_tex:filter_linear_mipmap,repeat_enable;
uniform sampler2D ao_tex:filter_linear_mipmap,repeat_enable;
uniform sampler2D roughness_tex:filter_linear_mipmap,repeat_enable;
uniform float wet_age=-1.0;
uniform float seed=0.0;
void fragment(){
	vec4 c=texture(image,UV);
	float birth=smoothstep(0.0,.16,wet_age);
	float wet_front=UV.x+.16*sin(UV.y*9.0+seed*6.0);
	float drying_front=(wet_age-.50)/.75;
	float wet=1.0-smoothstep(wet_front-.12,wet_front+.12,drying_front);
	ALBEDO=c.rgb*.29;
	vec2 p=UV*1.5;
	NORMAL_MAP=texture(normal_tex,p).rgb;
	AO=texture(ao_tex,p).r;
	ROUGHNESS=mix(texture(roughness_tex,p).r,.94,clamp(wet_age/1.2,0.0,1.0));
	ALPHA=c.a*.74*birth*wet;
}
