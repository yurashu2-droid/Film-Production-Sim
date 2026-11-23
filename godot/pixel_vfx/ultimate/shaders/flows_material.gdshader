shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform int role = 0;
uniform int layer = 0;
uniform float phase = 0.0;

void fragment() {
 vec2 cells=vec2(8.0,16.0);
 if(role==4) cells=vec2(5.0,22.0);
 vec2 p=(floor(UV*cells)+.5)/cells;
 float x=abs(p.x-.5)*2.0;
 float wave=.5+.5*sin(p.y*9.0-COLOR.r*4.0+sin(p.x*6.0+p.y*4.0));
 float band=floor(clamp(.25+wave*.50+(1.0-x)*.23,0.0,.99)*4.0)/3.0;
 vec3 dark=vec3(.025,.07,.16);
 vec3 bright=vec3(.10,.62,.68);
 if(role==1){dark=vec3(.02,.12,.24);bright=vec3(.16,.85,1.0);}
 if(role==2){dark=vec3(.07,.025,.22);bright=vec3(.46,.25,.95);}
 if(role==3){dark=vec3(.06,.18,.30);bright=vec3(.45,1.1,1.2);}
 if(role==4){dark=vec3(.035,.13,.22);bright=vec3(.3,.78,1.0);}
 if(role==5){dark=vec3(.23,.10,.055);bright=vec3(1.05,.64,.18);}
 if(role==6){dark=vec3(.055,.23,.30);bright=vec3(.45,1.0,1.12);}
 float edge=1.0-smoothstep(.68,1.0,x);
 float density=.30;
 if(layer==1) density=.44;
 if(layer==2) density=.61;
 float cooling=1.0-smoothstep(.65,1.0,COLOR.r);
 if(role==0) cooling=1.0-smoothstep(.33,1.0,COLOR.r);
 if(role==4){density=.36;cooling=1.0-smoothstep(.72,1.0,COLOR.r);edge*=sin(clamp(p.y,0.,1.)*3.14159);}
 if(role==3) density=.62;
 if(role==5) cooling=1.0-smoothstep(.55,1.0,COLOR.r);
 if(role==6){density=.75;cooling=1.0-smoothstep(.985,1.0,COLOR.r);}
 vec3 col=mix(dark,bright,band)*(.68+float(layer)*.19);
 ALBEDO=col;
 EMISSION=col*(role==3?.45:.12);
 ALPHA=edge*density*cooling*(.66+wave*.34);
}
