shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform float phase=0.0;
varying vec3 nw;
void vertex(){VERTEX.x+=0.11*sin(VERTEX.y*3.0-phase*3.0);nw=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){float l=dot(normalize(nw),normalize(vec3(-0.4,0.8,0.5)));ALBEDO=COLOR.rgb*(l>0.5?1.25:(l> -0.15?1.0:0.52));}
