shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,skip_vertex_transform;
uniform float width=0.3;
uniform float seed=0.0;
uniform float phase=0.0;
uniform float surviving=1.0;
uniform float fuel_stop=0.09;
varying float material_cool;
void vertex(){
 vec3 p=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec3 tangent=(MODELVIEW_MATRIX*vec4(NORMAL,0.0)).xyz;
 vec3 side=cross(tangent,normalize(p));
 side=dot(side,side)>0.000001?normalize(side):vec3(1.0,0.0,0.0);
 float q=UV.x;
 material_cool=COLOR.r;
 float material=COLOR.g;
 // Pressure crests migrate across a sheared belly. Independent left and right
 // shoulders avoid a symmetric teardrop or a stretched rod silhouette.
 float envelope=pow(max(0.0,sin(q*3.14159)),0.55);
 float crest=0.70+0.30*sin(material*8.0-phase*12.0+seed);
 float heat_width=pow(max(0.001,1.0-material_cool),0.45);
 float shrink=pow(surviving,0.45);
 float shoulder=UV.y<0.5?0.85+0.25*sin(material*11.0-phase*8.0+seed):0.88+0.24*cos(material*7.0-phase*9.0+seed);
 float cutoff=smoothstep(fuel_stop+0.12,fuel_stop+0.42,phase);
 float tail_alive=1.0-smoothstep(0.95-cutoff*0.35,1.03-cutoff*0.35,material);
 float local_width=width*envelope*crest*heat_width*shrink*tail_alive;
 float offset=0.20*sin(material*9.0-phase*8.0+seed)*local_width;
 VERTEX=p+side*((UV.y-0.5)*local_width*shoulder+offset);
 NORMAL=vec3(0.0,0.0,1.0);
}
void fragment(){
 float cool=material_cool;
 float edge=abs(UV.y-0.5)*2.0;
 float belly=exp(-pow((UV.x-(0.65-0.5*smoothstep(0.0,0.35,phase)))/0.20,2.0));
 float early=1.0-smoothstep(0.035,0.12,phase);
 vec3 yellow=vec3(4.0,1.3,0.08);
 vec3 orange=vec3(2.6,0.12,0.008);
 vec3 red=vec3(0.75,0.02,0.004);
 vec3 col=mix(yellow,orange,smoothstep(0.05,0.42,cool));
 col=mix(col,red,smoothstep(0.42,0.94,cool));
 col=mix(col,vec3(6.0,4.5,1.8),belly*early*0.65);
 // The moving hot ridge is inside the body; no stationary point core or sphere halo.
 col*=0.75+0.25*belly;
 ALBEDO=col;
 ALPHA=smoothstep(1.0,0.60,edge)*(1.0-smoothstep(0.55,1.0,cool));
}
