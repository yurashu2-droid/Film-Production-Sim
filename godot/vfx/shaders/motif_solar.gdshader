shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float phase = 0.0;
uniform float heat = 1.0;
void fragment(){
 float pulse=sin(UV.x*31.0-phase*10.0+sin(UV.x*13.0-phase*4.0)*1.7);
 float flank=pow(max(0.0,sin(UV.y*3.14159)),0.6);
 vec3 hot=mix(vec3(1.1,0.055,0.008),vec3(3.6,0.62,0.035),flank*(0.55+0.25*pulse));
 ALBEDO=mix(vec3(0.20,0.015,0.008),hot,heat);
 float channels=sin(UV.y*25.1327+sin(UV.x*17.0-phase*7.0)*1.4);
 ALPHA=0.12+0.72*smoothstep(-0.2,0.8,channels);
 EMISSION=ALBEDO*heat*0.8;
}


