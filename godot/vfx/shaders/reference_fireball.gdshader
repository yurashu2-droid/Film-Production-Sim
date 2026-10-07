shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform sampler2D noise_texture : repeat_enable,filter_linear;
uniform sampler2D flow_texture : repeat_enable,filter_linear;
uniform sampler2D flame_texture : repeat_enable,filter_linear;
uniform float phase=0.0;
uniform float pressure=0.01;
uniform float height=0.0;
uniform float remaining=1.0;
varying float height_band;
varying float angle_band;
varying vec3 world_normal;
void vertex(){
 vec3 n=normalize(VERTEX);
 float a=atan(n.z,n.x);float h=n.y*0.5+0.5;
 // Successive broad pressure lobes roll up the belly into the crown.
 float roll=sin(h*11.0-phase*7.5+a*2.0);
 float swell=sin(a*6.0+h*5.0-phase*2.8);
 float envelope=sin(h*3.14159);
 float radius=2.06*pressure*(1.0+envelope*(0.08*swell+0.065*roll));
 VERTEX=n*radius*vec3(1.16,0.85,1.10);
 VERTEX.x+=0.11*pressure*envelope*sin(h*7.0-phase*3.7);
 VERTEX.z+=0.09*pressure*envelope*cos(h*8.0-phase*3.4);
 VERTEX.y+=height+0.13*pressure*envelope*roll;
 // As the core ruptures, hot skin leaves upward and outward; the fragments
 // do not remain frozen on the original sphere while being erased.
 float release=smoothstep(1.95,2.35,phase);
 VERTEX.xz+=n.xz*release*(0.22+0.18*sin(a*5.0+h*8.0));
 VERTEX.y+=release*(0.2+0.8*h);
 height_band=h;angle_band=a/6.28318+0.5;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 // Broad fuel tongues climb from the belly. Each shoulder, tip and bend has
 // its own delayed crest; small noise only splits the tip, never the whole body.
 float base=0.30+min(phase,1.9)*0.22;
 float tongue=0.0;
 for(int i=0;i<7;i++){
  float seed=float(i)*1.71;
  float crest=sin(phase*4.7-seed);
  float center=float(i)/7.0+0.011*crest;
  center+=(height_band-base)*(0.045*sin(phase*3.5-seed*0.6));
  float dist=abs(fract(angle_band-center+0.5)-0.5);
  float width=0.059+0.011*sin(seed+phase*3.4);
  float shoulder=pow(max(0.0,1.0-dist/width),0.65);
  float reach=0.20+0.10*sin(seed*2.1)+0.055*crest+0.12*smoothstep(0.2,0.8,phase);
  tongue=max(tongue,shoulder*reach);
 }
 vec2 uv=vec2(angle_band*24.0,height_band*3.0-phase*1.3);
 vec3 flow=texture(flow_texture,uv*0.3).rgb;
 float fine=texture(flame_texture,vec2(angle_band*1.4,height_band-phase*0.55)+(flow.rg*2.0-1.0)*0.035).r;
 float boundary=base+tongue;
 float tip_zone=1.0-smoothstep(0.06,0.19,abs(height_band-boundary));
 boundary+=(fine-0.35)*0.18*tip_zone;
 float front=height_band-boundary;
 vec3 col=front>0.035?vec3(5.2,5.0,4.4):(front> -0.10?vec3(4.4,2.5,0.1):vec3(2.7,0.085,0.008));
 // The underside's coarser rolling channels remain dark-orange, never brown smoke.
 if(front< -0.18 && tongue<0.07){col=vec3(1.5,0.08,0.009);}
 float lit=dot(normalize(world_normal),normalize(vec3(-0.4,0.8,0.5)));
 col*=lit> -0.2?1.0:0.8;
 // Only this fireball layer spends the effect's single noise-hole budget.
 float ncrack=texture(noise_texture,vec2(angle_band*7.0,height_band*2.0-phase*0.4)).r;
 float crack=0.50+0.19*sin(angle_band*50.3+height_band*11.0-phase*2.0)+0.12*sin(angle_band*31.4-height_band*16.0)+0.3*(ncrack-0.5);
 if(remaining<0.99 && crack+0.08<1.0-remaining){discard;}
 ALBEDO=col;
}


