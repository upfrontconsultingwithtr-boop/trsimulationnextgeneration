shader_type spatial;
render_mode cull_disabled;
// Recolourable clothing. Vertex colour regions: R = top, G = bottom, B = outer layer.
// Tops/outer use the project's woven fabric detail; bottoms keep the original denim/wool luminance.
uniform vec3 top_color : source_color = vec3(0.8, 0.4, 0.25);
uniform vec3 bottom_color : source_color = vec3(0.3, 0.3, 0.32);
uniform vec3 outer_color : source_color = vec3(0.4, 0.27, 0.18);
uniform sampler2D orig_tex : source_color, filter_linear_mipmap;
uniform sampler2D fabric_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform float fabric_scale = 7.0;
void fragment() {
	vec4 o = texture(orig_tex, UV);
	if (o.a < 0.4) { discard; }
	float lum = dot(o.rgb, vec3(0.3, 0.59, 0.11));
	float fabric = texture(fabric_tex, UV * fabric_scale).r;
	vec3 w = COLOR.rgb / max(0.001, COLOR.r + COLOR.g + COLOR.b);
	vec3 col = top_color * w.r + bottom_color * w.g + outer_color * w.b;
	float shade_top = fabric * 0.96;   // no source luminance on tops: removes printed logos
	float shade_bottom = clamp(lum * 2.1, 0.35, 1.25);
	ALBEDO = col * mix(shade_top, shade_bottom, w.g);
	ROUGHNESS = 0.85;
	if (has_normal) { NORMAL_MAP = texture(normal_tex, UV).rgb; NORMAL_MAP_DEPTH = 0.8; }
}
