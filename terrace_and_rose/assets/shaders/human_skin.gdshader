shader_type spatial;
render_mode cull_back;
// Realistic skin: MakeHuman CC0 skin texture, tone tint, soft rim/sheen; skin under the worn outfit is discarded
uniform sampler2D skin_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint = vec3(1.0);
uniform int outfit_bit = -1;
uniform float roughness_v = 0.52;
void fragment() {
	if (outfit_bit >= 0) {
		int bits = int(round(COLOR.r * 31.0));
		if (((bits >> outfit_bit) & 1) == 1) { discard; }
	}
	vec3 c = texture(skin_tex, UV).rgb * tint;
	ALBEDO = c;
	ROUGHNESS = roughness_v;
	SPECULAR = 0.35;
	RIM = 0.18; RIM_TINT = 0.7;
	BACKLIGHT = c * 0.12;   // cheap subsurface glow on thin areas
}
