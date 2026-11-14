shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "px_common.gdshaderinc"
uniform float phase=0.0;
uniform float layer=0.0;
uniform float stream=0.0;
uniform float size=1.0;
uniform vec3 pal_0; uniform vec3 pal_1; uniform vec3 pal_2; uniform vec3 pal_3; uniform vec3 pal_4;
float parcel_age(float v){return v*2.18;}
vec3 path(float q,float e){
	float a=stream*2.399+sin(e*4.0+stream)*.13;
	vec2 radial=vec2(cos(a),sin(a));
	vec2 tangent=vec2(-sin(a),cos(a));
	vec3 p;
	if(q<1.02){
		float k=q/1.02;
		float r=2.5*(1.0-pow(k,1.65));
		vec2 h=radial*r+tangent*.35*sin(k*3.14159);
		p=vec3(h.x,mix(1.65+stream*.10,.49,pow(k,.75))+.27*sin(k*3.14159),h.y);
	}else if(q<1.16){
		vec2 h=radial*.08*sin((q-1.02)*22.4);
		p=vec3(h.x,.49+.06*sin((q-1.02)*22.4),h.y);
	}else{
		float s=q-1.16;
		vec2 h=tangent*s*2.65+radial*s*s*.62;
		p=vec3(h.x,.49+1.72*s-1.52*s*s,h.y);
	}
	return p;
}
void vertex(){
	float q=parcel_age(UV.y);
	float t=floor(phase*12.0)/12.0;float e=t-q;
	vec3 p=path(q,e);
	vec3 dir=normalize(path(q+.012,e)-path(q-.012,e)+vec3(.0001));
	vec3 side=normalize(cross(dir,vec3(0.0,1.0,0.0))+.0001);
	vec3 up=normalize(cross(side,dir));
	float shoulder=exp(-pow((q-.63)/.28,2.0))+exp(-pow((q-1.38)/.22,2.0));
	float belly=exp(-pow((q-.83)/.19,2.0));
	float breadth=(.16+shoulder*.20-belly*.055)*(1.0-layer*.29);
	p+=side*cos((UV.x-.5)*4.4)*breadth;
	p+=up*sin((UV.x-.5)*4.4)*breadth*.60;
	VERTEX=floor(p/.055+.5)*.055*size;
}
void fragment(){
	vec2 resolution=vec2(16.0,82.0);vec2 cell=floor(UV*resolution);vec2 p=(cell+.5)/resolution;
	float q=parcel_age(p.y);
	float e=floor(phase*12.0)/12.0-q;
	float a=stream*.115;float b=1.11+stream*.085;float c=1.76+stream*.045;
	bool supply=(e>=a && e<a+.43-layer*.032)||(e>=b && e<b+.37-layer*.025)||(e>=c && e<c+.44-layer*.032);
	if(!supply || q>2.10-layer*.04){discard;}
	float n=px_noise(vec2(cell.x*.41+stream*7.3+layer*2.5,cell.y*.18-e*4.2));
	float rim=abs(p.x-.5)*2.0;
	if(n<.44+rim*.13 || px_bayer(cell)>.86-rim*.16){discard;}
	float tone=layer<.5 ? .05+n*.2 : (layer<1.5 ? .33+n*.26 : .69+n*.29);
	if(q>1.02 && q<1.16 && layer>1.5){tone=.95;}
	ALBEDO=px_ramp(tone,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}



