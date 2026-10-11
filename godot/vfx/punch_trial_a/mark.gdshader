shader_type spatial;
// Warm opaque ink planes, with shoulder motion and root-to-tip supply cuts. No TIME/noise fade.
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 fill_color = vec3(1.35, 0.94, 0.25);
uniform vec3 ink = vec3(0.20, 0.075, 0.028);
uniform float age = 0.0;
uniform float phase = 0.0;
uniform bool piece = false;
uniform vec3 world_axis = vec3(1.,0.,0.);
uniform float layer_index = 0.0;
varying vec2 screen_flow;
void vertex() {
	vec2 projected = (VIEW_MATRIX * vec4(world_axis,0.0)).xy;
	screen_flow = length(projected) > 0.1 ? normalize(projected) : normalize(vec2(0.6,0.8));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz),0.,0.,0.), vec4(0.,length(MODEL_MATRIX[1].xyz),0.,0.),vec4(0.,0.,length(MODEL_MATRIX[2].xyz),0.),vec4(0.,0.,0.,1.));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge;
	if (piece) {
		float c = cos(phase), s = sin(phase);
		p = mat2(vec2(c,-s),vec2(s,c)) * p;
		float root = -0.78 + smoothstep(0.10,0.30,age) * 1.68;
		float width = (0.30 + 0.12 * sin(p.x * 3.0 + 0.5)) * (1.0 - smoothstep(0.40,0.9,p.x));
		edge = min(min(p.x - root,0.88 - p.x),width-abs(p.y + 0.10*sin(p.x*2.0)));
	} else {
		float hit = smoothstep(0.077,0.12,age);
		if (age < 0.078) {
			// Short bent glove-following comma, not an independent white speedline.
			p.x += 0.36;
			edge = min(0.29 - abs(p.x), 0.095 - abs(p.y - 0.12*sin(p.x*5.0)));
		} else {
			p.y *= 1.09;
			float angle = atan(p.y,p.x);
			float bend = smoothstep(0.17,0.46,age) * 0.23 * sin(angle*3.0+phase);
			float sector = floor((angle + 3.14159) / 6.28318 * 7.0);
			float shoulder = 0.49 + 0.15*sin(sector*2.7+0.4) + 0.12*sin(age*14.0+sector*1.9);
			float angular = abs(mod((angle+bend+phase)*7.0+3.14159,6.28318)-3.14159)/3.14159;
			float spike = pow(max(1.0-angular,0.0),1.65);
			float radius = (0.36 + spike*shoulder) * mix(0.36,1.0,hit);
			float cut = smoothstep(0.42+layer_index*0.025,0.66+layer_index*0.018,age);
			vec2 flow = normalize(screen_flow + vec2(0.0,phase*3.0));
			float root = mix(-1.15,1.13,cut);
			edge = min(radius-length(p),dot(p,flow)-root);
		}
	}
	if(edge < 0.0) discard;
	ALBEDO = mix(ink,fill_color,smoothstep(0.026,0.064,edge));
}
