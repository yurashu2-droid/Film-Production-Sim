shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform int mode=0;
uniform float layer=0.0;
uniform float phase=0.0;
uniform float opened=0.0;
uniform float closed=0.0;
uniform float charge=0.0;
float band(float x,float center,float width){return 1.0-step(width,abs(x-center));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){
 vec2 p=(UV-.5)*2.0;
 float a=atan(p.y,p.x);
 if(mode!=3){
  VERTEX.z+=(sin(a*5.0-phase*.85+layer)*.016+sin(a*3.0+phase*.55)*.022)*length(p);
  VERTEX.xy+=normalize(p+vec2(.0001))*sin(a*7.0-phase*.7+layer)*.009;
 }
}
void fragment(){
 vec2 cells=floor(UV*96.0);
 vec2 p=((cells+.5)/96.0-.5)*2.0;
 float r=length(p);
 float angle=atan(p.y,p.x);
 float turn=fract(angle/TAU+.5);
 float a=angle+phase*(mode==0?.045:-.095)+layer*.17;
 float octant=floor(turn*8.0);
 float local=fract(turn*8.0);
 // Alternate angular sections reveal and leave at separate depth timings.
 float order=mod(octant*3.0+layer,8.0)/8.0;
 if(mode!=3){
  if(opened<order*.32+local*.67)discard;
  if(closed>0.0 && closed>order*.28+local*.70+.02)discard;
 }
 float release=smoothstep(12.65,13.1,phase)*(1.0-smoothstep(13.5,15.4,phase));
 float aperture=mix(.27,.60,smoothstep(6.5,10.0,phase))-.035*charge+.045*release;
 vec3 navy=vec3(.012,.026,.10);
 vec3 teal=vec3(.065,.41,.58);
 vec3 ice=vec3(.38,1.12,1.36);
 vec3 gold=vec3(1.30,.78,.20);
 vec3 white=vec3(1.6,1.85,1.65);
 vec3 color=teal;
 float mask=0.0;
 if(mode==0){
  float segment=fract(a/TAU*(layer<1.0?12.0:6.0));
  float radius=layer<1.0?.945:.862+sin(a*6.0-phase*.35)*(.009+.012*charge);
  float rim=band(r,radius,layer<1.0?.016:.022);
  float diamonds=step(abs(segment-.5)*.21+abs(r-.898),.027);
  float rail=band(r,.905,.009)*step(.72,fract(a/TAU*24.0));
  float cuts=step(.10,segment)*step(segment,.86);
  mask=max(rim*cuts,max(diamonds,rail));
  color=mix(gold*.34,gold*.72,step(.88,r));
  color=mix(color,white,diamonds*.28+charge*.18);
 }else if(mode==1){
  float shoulder=.73+.047*sin(a*6.0-phase*.83)+.018*sin(a*13.0+phase*.65);
  float channel=band(r,shoulder,.045)+band(r,shoulder+.061,.011);
  float feather=step(.30,sin(a*9.0-r*19.0+phase*1.3))*band(r,shoulder,.062);
  mask=max(channel,feather*.85);
  color=mix(vec3(.075,.11,.34),teal,step(.7,channel));
  color+=ice*band(r,shoulder+.061,.011)*.25;
  color*=.65+.12*mod(layer,3.0)+charge*.18;
 }else if(mode==2){
  float petal=pow(abs(cos(a*6.0)),.6);
  float iris=aperture+.032*petal+.028*sin(a*3.0-phase*.8);
  float fold=pow(max(0.0,sin(a*6.0-phase*.3)),3.0);
  mask=band(r,iris,.016+.035*fold*(1.0-release*.6))+band(r,iris-.042,.008)*step(.45,fract(a/TAU*18.0));
  color=mix(ice*.60,white*.72,charge*.30);
 }else{
  if(r>min(aperture-.015,opened*.66) || p.x+1.0<closed*2.2)discard;
  vec2 q=p;
  float spin=phase*.075+r*3.0;
  q=mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin)))*q;
  float cloud=sin(q.x*8.0+sin(q.y*6.0-phase*.16)*1.4+phase*.13)*sin(q.y*7.0+q.x*3.0-phase*.21);
  float strata=sin(q.y*16.0+sin(q.x*7.0+phase*.20)*2.3);
  float depth=smoothstep(.08,.60,r);
  color=navy*.14+vec3(.004,.010,.020)*smoothstep(.05,.8,cloud);
  color+=vec3(.008,.018,.032)*smoothstep(.5,.95,cloud)*step(.35,strata)*depth;
  vec2 stars=floor(q*42.0);
  float star=step(.993,hash(stars))*step(length(fract(q*42.0)-.5),.30);
  color+=ice*star*(.22+.14*sin(phase*1.8+hash(stars)*20.0));
  mask=1.0;
 }
 if(mask<.5)discard;
 ALBEDO=color;
}
