shader_type spatial;
render_mode cull_disabled;
uniform float age = 0.0;
varying vec2 point;
varying float height;

float surface(vec2 p) {
	float r = length(p);
	float rise = smoothstep(0.1, 0.65, age);
	float settle = 1.0-smoothstep(2.75, 3.65, age);
	vec2 field = vec2(0.6*sin(age*1.65), 0.45*cos(age*1.2));
	vec2 q = p-field;
	q += vec2(0.19*sin(p.y*2.4+age*1.3),0.16*sin(p.x*2.1-age*1.5));
	float lattice = (cos(q.x*7.2)+cos(q.x*3.6+q.y*6.235)+cos(q.x*3.6-q.y*6.235))/3.0;
	float spikes = pow(max(lattice, 0.0), 1.7);
	float travelling = 0.3+0.7*exp(-pow((length(q)-(0.35+age*0.49))/0.68,2.0));
	float crown_radius = 1.0+0.18*sin(age*2.0);
	float crown = exp(-pow((r-crown_radius)/0.25,2.0));
	float impulse = exp(-pow((age-2.08)/0.36,2.0));
	float tooth = pow(0.5+0.5*cos(atan(p.y,p.x)*11.0-age*2.4), 1.5);
	float edge = 1.0-smoothstep(2.35,2.85,r);
	float ripple = 0.045*sin(r*10.0-age*7.0)*exp(-r*0.6)*rise*settle;
	return max(0.025,0.08+rise*settle*(1.35*spikes*travelling+1.35*impulse*crown*(0.28+tooth))+ripple)*edge;
}

void vertex() {
	point = VERTEX.xz;
	height = surface(point);
	VERTEX.y = height;
	float e = 0.014;
	float dx = (surface(point+vec2(e,0.0))-surface(point-vec2(e,0.0)))/(2.0*e);
	float dz = (surface(point+vec2(0.0,e))-surface(point-vec2(0.0,e)))/(2.0*e);
	NORMAL = normalize(vec3(-dx,1.0,-dz));
}

void fragment() {
	float radius = 2.8*smoothstep(0.0,0.32,age)*(1.0-smoothstep(3.65,4.32,age));
	float shape = length(point)/(1.0+0.035*sin(atan(point.y,point.x)*5.0));
	if (shape > radius) { discard; }
	float rim = pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.0);
	ALBEDO = mix(vec3(0.012,0.018,0.025),vec3(0.15,0.18,0.2),rim*0.5);
	METALLIC = 0.35;
	ROUGHNESS = 0.23;
	SPECULAR = 0.8;
	EMISSION = vec3(0.018,0.026,0.035)+rim*vec3(0.1,0.075,0.035);
}
