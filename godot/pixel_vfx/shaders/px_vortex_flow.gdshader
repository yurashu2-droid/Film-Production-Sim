shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "px_common.gdshaderinc"
uniform float phase=0.0;
uniform float layer=0.0;
uniform float stream=0.0;
uniform float mode=0.0;
uniform float size=1.0;
uniform vec3 pal_0; uniform vec3 pal_1; uniform vec3 pal_2; uniform vec3 pal_3; uniform vec3 pal_4;
float travel(float v) {return mode<.5 ? v*1.30 : v*.55;}
void vertex(){
	float u=UV.x;float v=UV.y;
	float t=floor(phase*12.0)/12.0;
	float e=t-travel(v);
	float shoulder=exp(-pow((e-.48)/.21,2.0))+exp(-pow((e-1.63)/.28,2.0));
	float belly=exp(-pow((e-.70)/.28,2.0))+exp(-pow((e-1.90)/.31,2.0));
	float angle=stream*2.399+(u-.5)*1.2+v*4.3-e*1.55+layer*.15;
	float r=(1.15-v*.61)*(1.0-layer*.28);
	r*=1.0+.35*shoulder-.16*belly+.13*sin(angle*3.0+e*2.5);
	vec3 p;
	if(mode<.5){
		p=vec3(cos(angle)*r,v*3.15+.06,sin(angle)*r);
		p.x+=sin(e*2.1+v*1.5)*.23*v;
		p.z+=cos(e*1.8-v*2.1)*.21*v;
		p.y+=shoulder*.16*cos(angle*2.0)-belly*.10;
	}else{
		angle=stream*2.399+(u-.5)*1.25+v*4.2-e*1.25+layer*.15;
		r=(1.65-v*1.10)*(1.0-layer*.17)+shoulder*.23;
		p=vec3(cos(angle)*r,.055+v*.48+sin(u*3.14159)*(.22+belly*.12),sin(angle)*r);
	}
	VERTEX=floor(p/.055+.5)*.055*size;
}
void fragment(){
	vec2 cell=floor(UV*vec2(62.0,56.0));
	vec2 p=(cell+.5)/vec2(62.0,56.0);
	float e=floor(phase*12.0)/12.0-travel(p.y);
	float stop_time=mode<.5 ? 2.85+layer*.07 : 2.75+layer*.05;
	float start_time=stream*.095+layer*.035;
bool supply=(e>=start_time && e<.77+start_time)||(e>=.95+start_time && e<1.73+start_time)||(e>=1.88+start_time && e<stop_time);
if(!supply){discard;}
	float n=px_noise(vec2(cell.x*.31+layer*5.7+stream*6.3,cell.y*.21-e*3.1));
	float edge=abs(p.x-.5)*2.0;
	if(n<.43+layer*.025+edge*.12 || px_bayer(cell)>.84){discard;}
	float tone=layer<.5 ? .04+n*.22 : (layer<1.5 ? .31+n*.26 : .68+n*.30);
	ALBEDO=px_ramp(tone,cell,pal_0,pal_1,pal_2,pal_3,pal_4);
}


