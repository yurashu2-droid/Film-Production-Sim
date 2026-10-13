shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
uniform float phase=0.0;
uniform float hit=0.0;
uniform float layer=0.0;
uniform float packet=0.0;
uniform float size=1.0;
uniform sampler2D grain:filter_linear_mipmap,repeat_enable;
float start(){return hit<.5?.55:(hit<1.5?1.05:2.05);}
float delay(){return packet*(hit>1.5?.32:.10);}
float life(){return hit<.5?.43:(hit<1.5?.46:(packet<.5?2.72:2.36));}
void vertex(){
 float u=UV.x;float v=UV.y;
 float q=phase-start()-delay()-layer*.035;
 float progress=max(0.0,q);
 float strength=hit<.5?.67:(hit<1.5?.51:1.0);
 float side=packet<.5?-1.0:1.0;
 float travel=packet<.5?.88:1.42;
 float angle=(u-.5)*2.50;
 float crest=exp(-pow((u-(.10+progress*.56))/ .22,2.0));
 float belly=exp(-pow((u-(.10+max(0.0,progress-.19)*.56))/.29,2.0));
 float r=.68+strength*.40+min(progress,1.15)*.14;
 float width=r*(packet<.5?1.05:1.24);
 float x=side*.73+sin(angle)*width;
 x+=side*progress*.12+(crest-belly*.56)*(.18+v*.23);
 float arch=pow(max(0.0,sin(u*PI)),.54);
 float height=(1.65+strength*.95)*arch;
 height*=.58+smoothstep(.0,.25,progress)*.42;
 height+=(belly-crest*.7)*.50;
 float y=.08+v*height;
 float z=-.8+progress*travel+(cos(angle)-.50)*r*.72;
 z+=v*v*(packet<.5?.45:-.38)+(crest-belly*.4)*.45*v;
 z+=layer*.16+sin(u*9.0-progress*1.8+packet)*.10*v;
 if(hit>1.5){
  float released=max(0.0,progress-1.40);
  y+=released*(.15+v*.64)*(1.0-layer*.22);
  x+=side*released*v*.22;
 }
 VERTEX=vec3(x,y,z)*size;
}
void fragment(){
 float u=UV.x;float v=UV.y;
 float q=phase-start()-delay()-layer*.035;
 float g=texture(grain,vec2(u*1.75+v*.50-q*.39,v*1.35-q*.26)+packet*.56+hit*.23+layer*.17).r;
 float folds=texture(grain,vec2(u*2.6+v*.30-q*.21,v*.76+q*.16)+packet*.33+layer*.31).r;
 float pores=smoothstep(.37,.58,g+folds*.14);
 float side=smoothstep(.0,.12,u)*(1.0-smoothstep(.84,1.0,u));
 float vertical=smoothstep(.0,.08,v)*(1.0-smoothstep(.80,1.0,v));
 float born=smoothstep(.0,.07,q-v*.035-abs(u-.35)*.045);
 float empty=(q-(life()-(hit>1.5?.68:.20)))/(hit>1.5?.58:.16);
 if(hit>1.5&&layer>.5&&layer<1.5) empty=(q-1.24)/.60;
 if(hit>1.5&&layer>1.5) empty=(q-.48)/.44;
 float departing=smoothstep(empty-.10,empty+.10,v);
 vec3 color=vec3(.085,.045,.18);
 float alpha=.36;
 if(layer>.5&&layer<1.5){color=mix(vec3(.12,.28,.54),vec3(.35,.72,1.04),g);alpha=.52;}
 if(layer>1.5){
  color=mix(vec3(1.25,1.65,2.2),vec3(1.9,1.5,.93),smoothstep(.68,.90,u));
  pores*=smoothstep(.49,.65,folds);
  vertical*=exp(-pow((v-.60)/.17,2.0));alpha=.34;
 }
 ALBEDO=color;
 ALPHA=pores*side*vertical*born*departing*alpha;
}
