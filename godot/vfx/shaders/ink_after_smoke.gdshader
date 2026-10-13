shader_type spatial;
render_mode unshaded,cull_back,shadows_disabled,depth_draw_never;
uniform float phase=0.0;
uniform float layer=0.0;
uniform float size=1.0;
uniform vec3 bounds_center=vec3(0);
uniform float ray_step=.09;
uniform vec3 sources[12];
uniform vec3 velocities[12];
uniform vec3 shade=vec3(.018,.014,.02);
uniform vec3 hot=vec3(.16,.12,.09);
uniform sampler2D grain:filter_linear_mipmap,repeat_enable;
varying vec3 entry;
varying vec3 eye;
void vertex(){
 entry=VERTEX/size+bounds_center;
 eye=(inverse(MODEL_MATRIX)*INV_VIEW_MATRIX[3]).xyz/size+bounds_center;
}
vec3 anchor(int i,float flow,float u){
 float t=max(0.0,phase);
 float carried=(1.0-exp(-4.2*t))/4.2;
 vec3 p=sources[i]+velocities[i]*carried;
 float shoulder=exp(-pow((t-(.08+u*.13+flow*.035))/.22,2.0));
 float neck=exp(-pow((t-(.23+u*.11+flow*.045))/.26,2.0));
 float release=1.0-exp(-3.5*t);
 vec3 lateral=vec3(.07*sin(flow*1.9),sin(flow*1.75+t)*.30,cos(flow*1.3-t)*.40);
 p+=lateral*release*(.26+u*.48)*(shoulder-neck*.50+min(t,.8)*.7);
 p+=lateral*release*sin(u*PI)*sin(t*3.8+flow*1.3)*.80;
 // Existing parcels fan sideways. There is no independent rise or new smoke origin.
 p.y+=(u-.5)*sin(flow*1.6+t*1.8)*release*.15;
 return p;
}
float segment_density(vec3 p,vec3 a,vec3 b,float u0,float u1,float flow){
 vec3 axis=b-a;
 float h=clamp(dot(p-a,axis)/max(.0001,dot(axis,axis)),0.0,1.0);
 float u=mix(u0,u1,h);
 vec3 delta=p-mix(a,b,h);
 float base=layer<.5?.14:(layer<1.5?.075:.025);
 float opening=max(0.0,phase-(flow*.035+u*.025));
 float spread=layer<.5?.12:(layer<1.5?.085:.04);
 float radius=base+opening*spread+max(0.0,opening-.35)*.035;
 radius*=.62+.38*pow(max(0.0,sin(u*PI)),.65);
 float mass=pow(base/max(base,radius),2.7);
 float distance=length(delta)/max(.012,radius);
 float porous=texture(grain,p.yz*2.5+vec2(u*.42-phase*.22,flow*.43)).r;
 float density=exp(-distance*distance*2.6)*(.52+.48*smoothstep(.22,.65,porous));
 // Soft material caps: a closest-point clamp must not turn each flow into a board.
 float ends=.18+.82*pow(max(0.0,sin(u*PI)),.70);
 float ending=layer<.5?(.20+flow*.035+u*.16):(layer<1.5?(.10+flow*.012+u*.07):(.025+flow*.005+u*.03));
 float duration=layer<.5?.24:(layer<1.5?.10:.05);
 float alive=1.0-smoothstep(ending,ending+duration,phase);
 return density*mass*ends*alive;
}
void fragment(){
 vec3 ray=normalize(entry-eye);
 vec3 p=entry;
 float trans=1.0;
 vec3 sum=vec3(0);
 for(int sample=0;sample<48;sample++){
  float density=0.0;
  for(int flow=0;flow<4;flow++){
   int i=flow*3;
   vec3 a=anchor(i,float(flow),.0);
   vec3 b=anchor(i+1,float(flow),.5);
   vec3 c=anchor(i+2,float(flow),1.0);
   density+=segment_density(p,a,b,.0,.5,float(flow));
   density+=segment_density(p,b,c,.5,1.0,float(flow));
  }
  float optical=layer<.5?18.0:(layer<1.5?15.0:19.0);
  float alpha=1.0-exp(-density*ray_step*optical);
  float warmth=layer<.5?.03:(layer<1.5?.62:.18);
  vec3 color=mix(shade,hot,warmth);
  sum+=trans*alpha*color;
  trans*=1.0-alpha;
  p+=ray*ray_step;
 }
 float opacity=1.0-trans;
 ALBEDO=sum/max(.001,opacity);
 float born=smoothstep(.0,.045,phase);
 ALPHA=opacity*born*(layer<.5?.70:(layer<1.5?.56:.33));
}
