shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float phase=0.0;
uniform float layer=0.0;
uniform float seed=0.0;
uniform float elapsed=0.0;
uniform float emitted_first=0.0;
uniform float emitted_last=0.2;
uniform float burn=1.5;
void fragment(){
 float material_age=elapsed-mix(emitted_last,emitted_first,UV.y);
 float angle=UV.x*3.14159;
 // Permanent flowing channels, never a lifetime-dependent random-hole dissolution.
 float channel=sin(angle*2.0+UV.y*9.0-material_age*5.8+seed)+.32*sin(angle*5.0-UV.y*15.0+phase*2.0);
 float density=smoothstep(layer<.5?.30:(layer<1.5?-.10:-.5),.95,channel);
 float envelope=pow(max(0.0,sin(UV.y*3.14159)),.3);
 float cold=smoothstep(.25,burn,material_age);
 float cool_end=1.0-smoothstep(burn-.17,burn,material_age);
 float center=.67+.14*sin(elapsed*2.7+seed);
 float kernel=exp(-pow((UV.y-center)/.23,2.0));
 vec3 color=layer<.5?mix(vec3(.10,.032,.012),vec3(.035,.022,.022),cold):
 (layer<1.5?mix(vec3(.35,.085,.02),vec3(2.8,.9,.08),kernel*(1.0-cold)):mix(vec3(.55,.14,.02),vec3(5.0,3.8,1.8),kernel*(1.0-cold)));
 ALBEDO=color;
 EMISSION=layer<.5?vec3(0.0):color*kernel*(1.0-cold)*.75;
 ALPHA=density*envelope*cool_end*(layer<.5?.25:(layer<1.5?(.23+.60*kernel):kernel*.94));
}
