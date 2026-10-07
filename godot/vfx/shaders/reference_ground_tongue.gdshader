shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform float phase=0.0;
uniform float seed=0.0;
uniform float detach=0.0;
uniform float lead=0.0;
uniform sampler2D flame_texture : repeat_enable,filter_linear;
varying float along;
varying float around;
void vertex(){
 float v=UV.y;float a=UV.x*6.28318;
 float front=1.0-exp(-phase*7.0);
 float q=mix(min(detach,front),front,v);
 // Pressure crest travels from the broad root to a bent and sharply tapering tip.
 float pulse=0.74+0.26*sin(q*11.0-phase*9.0+seed);
 float radius=mix(0.43,0.85,lead)*pow(max(0.00001,sin(v*3.14159)),0.55)*(1.0-q*0.62)*pulse;
 radius*=pow(max(0.00001,1.0-detach),0.6);
 float fold=smoothstep(0.12,0.6,phase);
 float bend=0.38*sin(q*5.0-phase*5.0+seed)*q;
 float x=(mix(2.5,3.6,lead)*q-mix(1.0,2.4,lead)*q*q*fold)+bend;
 float height=mix(1.55,3.25,lead)+0.35*sin(seed);
 float y=0.1+height*pow(q,1.3)*(0.24+0.76*fold)+detach*1.1;
 y+=0.42*sin(q*4.0-phase*4.5+seed)*q*q;
 // The height-dependent transverse field makes the belly run outwards then fold upwards.
 x+=0.18*sin(q*4.0-phase*3.5+seed)*q*(1.0-q);
 VERTEX=vec3(x+cos(a)*radius,y,sin(a)*radius*0.60+0.24*sin(q*5.0-phase*3.5+seed)*q);
 along=q;around=UV.x;
}
void fragment(){
 float fire=texture(flame_texture,vec2(around+seed*0.2,along*0.9-phase*0.8)).r;
 vec3 col=fire>0.70 || along>0.92?vec3(3.6,2.05,0.045):(fire>0.12?vec3(2.6,0.14,0.012):vec3(1.3,0.055,0.003));
 float cooling=smoothstep(0.25,0.95,detach);
 ALBEDO=mix(col,vec3(0.55,0.045,0.003),cooling);
}

