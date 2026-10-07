shader_type spatial;
render_mode cull_disabled;
uniform float phase = 0.0;
void fragment(){
 float folds=sin(UV.x*22.0-phase*9.0+sin(UV.y*19.0+phase*3.0));
 float foam=smoothstep(0.62,0.95,folds)*smoothstep(0.3,1.0,UV.x);
 ALBEDO=mix(vec3(0.025,0.34,0.50),vec3(0.64,0.89,0.94),foam);
 ALPHA=0.75;
 ROUGHNESS=0.33;
 METALLIC=0.15;
 EMISSION=vec3(0.035,0.14,0.18);
}

