shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 wind = vec3(0.0);
uniform float gust_time = 0.0;

void vertex() {
	// Grass card UV has its roots at y=1.
	float tip = 1.0 - UV.y;
	float sway = 0.73 + 0.27 * sin(gust_time * 18.0 + VERTEX.x * 1.1 + VERTEX.z * 0.8);
	VERTEX.xz += wind.xz * tip * tip * sway;
	VERTEX.y -= length(wind.xz) * tip * tip * 0.30;
}

void fragment() {
	vec4 blade = texture(grass_texture, UV);
	ALBEDO = blade.rgb * COLOR.rgb;
	ALPHA = blade.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.3, 0.36, 0.16);
}
