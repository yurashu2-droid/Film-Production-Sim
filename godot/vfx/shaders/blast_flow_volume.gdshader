shader_type spatial;
render_mode unshaded,blend_mix,cull_front,depth_draw_never,shadows_disabled;
uniform vec4 parcels[32];
uniform vec4 motion[32];
uniform float phase=0.0;
varying vec3 object_pos;
varying vec3 eye;
vec3 curl(vec3 p){
 return vec3(cos(p.x+p.y)-cos(p.x+p.z),cos(p.y+p.z)-cos(p.x+p.y),cos(p.x+p.z)-cos(p.y+p.z));
}
void vertex(){object_pos=VERTEX;eye=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;}
void fragment(){
 vec3 dir=normalize(object_pos-eye);
 vec3 lo=vec3(-6.0,-5.5,-6.0);
 vec3 hi=vec3(6.0,5.5,6.0);
 vec3 safe=sign(dir)*max(abs(dir),vec3(0.00001));
 vec3 t0=(lo-eye)/safe;vec3 t1=(hi-eye)/safe;
 vec3 tn=min(t0,t1);vec3 tf=max(t0,t1);
 float begin=max(0.0,max(tn.x,max(tn.y,tn.z)));
 float end=min(tf.x,min(tf.y,tf.z));
 float stride=max(0.0,end-begin)/40.0;
 vec3 result=vec3(0.0);float transmit=1.0;
 for(int j=0;j<40;j++){
  vec3 p=eye+dir*(begin+(float(j)+0.5)*stride);
  // Shared eddies fold the full density contour. No static sphere silhouette underneath.
  float cooled=smoothstep(0.9,1.5,phase);
  vec3 advected=p+curl(p*1.8+vec3(-phase*2.8,phase*0.8,phase*1.7))*mix(0.42,0.25,cooled);
  advected+=curl(advected*4.5+vec3(phase,-phase*2.0,phase*0.6))*mix(0.14,0.04,cooled);
  float density=0.0;float temperature=0.0;vec3 gradient=vec3(0.0);
  for(int i=0;i<32;i++){
   vec3 center=parcels[i].xyz;
   float amount=parcels[i].w;
   if(i%8<7 && parcels[i+1].w>0.001){
    vec3 segment=parcels[i+1].xyz-center;
    float fraction=clamp(dot(advected-center,segment)/max(0.00001,dot(segment,segment)),0.0,1.0);
    center+=segment*fraction;
    amount=mix(amount,parcels[i+1].w,fraction);
   }
   vec3 delta=advected-center;
   vec3 v=motion[i].xyz;
   vec3 axis=normalize(v+vec3(0.0001));
   float along=dot(delta,axis);
   float d2=dot(delta,delta)-along*along*0.3;
   // Local material coordinates move with each sample; positive modulation never cuts holes.
   float eddy=0.76+0.24*sin(delta.y*7.0+float(i))*sin(delta.x*5.0+delta.z*6.0);
   float contribution=exp(-d2*2.1)*amount*eddy;
   density+=contribution;temperature+=contribution*motion[i].w;gradient-=delta*contribution*3.8;
  }
  // Broad continuous eddies perturb density itself, not a surface texture/discard.
  float hot=temperature/max(0.0001,density);
  density*=smoothstep(0.08,0.4,density);
  float alpha=1.0-exp(-density*stride*3.8);
  vec3 smoke=mix(vec3(0.14,0.105,0.09),vec3(0.43,0.34,0.28),clamp(p.y*0.12+0.8,0.0,1.0));
  float surface=clamp(length(gradient)/max(density,0.1)*0.2,0.0,1.0);
  vec3 fire=mix(vec3(2.1,0.16,0.018),vec3(3.0,1.65,0.35),smoothstep(0.5,0.95,hot)*(1.0-surface*0.9));
  float lighting=0.55+0.45*clamp(dot(normalize(-gradient+vec3(0.0001)),normalize(vec3(-0.4,0.8,0.5))),0.0,1.0);vec3 col=mix(smoke*lighting,fire,smoothstep(0.12,0.65,hot));
  result+=transmit*alpha*col;transmit*=1.0-alpha;
 }
 ALPHA=1.0-transmit;
 ALBEDO=result/max(0.0001,ALPHA);
}


