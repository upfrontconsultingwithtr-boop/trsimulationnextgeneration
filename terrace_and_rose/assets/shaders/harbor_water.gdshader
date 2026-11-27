shader_type spatial;
render_mode cull_disabled;

varying vec2 sea_position;

void vertex() {
	sea_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float ripple = sin(sea_position.x * 4.2 + sea_position.y * 1.1 + TIME * 1.1);
	float swell = sin(sea_position.x * 2.1 - sea_position.y * 0.46 + TIME * 1.65);
	float detail = sin(sea_position.y * 6.4 + sea_position.x * 1.4 - TIME * 0.9);
	float shore_distance = max(0.0, 2.5 - sea_position.x);
	float shallows = 1.0 - smoothstep(0.0, 13.0, shore_distance);
	vec3 water = mix(vec3(0.027, 0.16, 0.23), vec3(0.093, 0.36, 0.35), shallows);
	water += (ripple * 0.012 + swell * 0.022) * vec3(0.4, 0.8, 1.0);
	float strand = abs(shore_distance - 0.22 - sin(sea_position.y * 0.55 + TIME * 1.3) * 0.15);
	float foam = (1.0 - smoothstep(0.025, 0.24, strand)) * (0.55 + detail * 0.2);
	ALBEDO = mix(water, vec3(0.70, 0.84, 0.77), foam);
	ROUGHNESS = mix(0.25, 0.64, foam);
	SPECULAR = 0.58;
	NORMAL_MAP = vec3(0.5 + ripple * 0.035, 0.5 + swell * 0.042, 1.0);
}
