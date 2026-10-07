shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform sampler2D noise_texture : repeat_enable,filter_linear;
uniform sampler2D flow_texture : repeat_enable,filter_linear;
uniform float phase=0.0;
uniform float pressure=0.01;
uniform float supply=1.0;
uniform float seed=0.0;
varying float height_band;
varying vec3 coords;
void vertex(){
 vec3 n=normalize(VERTEX);float h=n.y*0.5+0.5;
 float moving=sin(h*9.0-phase*7.0+seed);
 float swelling=1.0+0.14*sin(atan(n.z,n.x)*4.0+h*6.0-phase*4.0+seed)*sin(h*3.14159);
 vec3 p=n*vec3(1.45,0.74,1.1)*pressure*swelling;
 p.y+=0.7*pressure;
 float crown=smoothstep(0.15,0.95,h);
 p.x+=crown*pressure*(0.5*sin(phase*5.0-h*4.0+seed)+0.35);
 p.y+=crown*pressure*0.19*moving;
 float alive=max(0.001,supply);
 p.y*=pow(alive,0.55+0.8*h);
 p.x*=pow(alive,0.7);p.z*=pow(alive,0.7);
 VERTEX=p;coords=p;height_band=h;
}
void fragment(){
 vec2 uv=vec2(coords.x*0.55+seed,height_band*1.2-phase*1.65);
 vec3 field=texture(flow_texture,uv).rgb;
 float n=texture(noise_texture,uv+(field.rg*2.0-1.0)*vec2(0.025,0.06)).r;
 float band=0.5+0.23*sin(coords.x*2.2-height_band*3.0+phase*5.0+seed)+0.1*(n-0.5);
 vec3 col=band>0.4?vec3(2.6,0.14,0.008):vec3(1.25,0.038,0.003);
 float edge=1.0-abs(dot(normalize(NORMAL),normalize(VIEW)));
 if(edge>0.91 && band>0.43){col=vec3(3.6,2.0,0.045);}
 float cool=smoothstep(2.15,2.65,phase);
 ALBEDO=mix(col,vec3(0.2,0.055,0.025),cool);
}
