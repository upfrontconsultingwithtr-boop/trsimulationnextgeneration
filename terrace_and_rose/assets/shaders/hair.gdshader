shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Hair cards: original strand texture's luminance and alpha, recoloured to the character's hair colour
uniform sampler2D hair_tex : source_color, filter_linear_mipmap;
uniform vec3 hair_color : source_color = vec3(0.1, 0.08, 0.06);
uniform float alpha_cut = 0.45;
void fragment() {
	vec4 t = texture(hair_tex, UV);
	if (t.a < alpha_cut) { discard; }
	float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	ALBEDO = hair_color * clamp(0.55 + lum * 1.6, 0.4, 1.6);
	ROUGHNESS = 0.55;
	SPECULAR = 0.45;
	ANISOTROPY = 0.6;
	BACKLIGHT = hair_color * 0.2;
}
