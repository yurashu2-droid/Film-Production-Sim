shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform sampler2D noise_texture : repeat_enable,filter_linear;
uniform float phase=0.0;
uniform float height=1.0;
uniform float start=0.0;
uniform float width=1.0;
varying float band;
varying float angle;
void vertex(){
 float v=UV.y;float a=UV.x*6.28318;
 float y=mix(start,height,v);
 float waist=0.18+0.23*pow(v,3.0)+0.09*(1.0-v);
 float pulse=0.85+0.15*sin(v*12.0-phase*13.0+a*2.0);
 VERTEX=vec3(cos(a)*waist*width*pulse,y,sin(a)*waist*width*pulse);
 VERTEX.x+=sin(v*5.0-phase*4.0)*0.09*v*width;
 band=v;angle=UV.x;
}
void fragment(){
 float flow=texture(noise_texture,vec2(angle*3.0,band*1.4-phase*2.7)).r;
 ALBEDO=flow>0.92?vec3(4.0,2.4,0.08):(flow>0.78?vec3(2.5,0.18,0.012):vec3(0.75,0.017,0.004));
}

