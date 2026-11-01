shader_type spatial;
render_mode cull_back, depth_draw_never;

uniform sampler2D block_atlas : source_color, filter_nearest;

void fragment() {
	vec4 tex = texture(block_atlas, UV);
	ALBEDO = OUTPUT_IS_SRGB ? pow(tex.rgb, vec3(2.2)) : tex.rgb;
	ALPHA = tex.a;
	ROUGHNESS = 0.15;
	SPECULAR = 0.25;
}
