shader_type spatial;
render_mode specular_disabled;

uniform sampler2D block_atlas : source_color, filter_nearest;
uniform vec3 cool_shade : source_color = vec3(0.53, 0.65, 0.78);
uniform bool wind_enabled = true;

void vertex() {
	// Wind markers are assigned only to leaves and separate grass blades.
	// Every vertex of a given cube receives the same phase and translation.
	if (wind_enabled && COLOR.a < 0.3) {
		float phase = dot(UV2, vec2(0.63, 0.47));
		float amplitude = COLOR.a > 0.2 ? 0.028 : COLOR.a * 0.25;
		float wave = sin(TIME * 1.8 + phase) + sin(TIME * 3.4 + phase * 1.3) * 0.25;
		VERTEX += vec3(wave, sin(TIME * 1.4 + phase) * 0.12, cos(TIME * 1.6 + phase) * 0.6) * amplitude;
	}
}

void fragment() {
	ivec2 tex_sz = textureSize(block_atlas, 0);
	if (tex_sz.x > 1) {
		vec4 tex = texture(block_atlas, UV);
		// The Compatibility atlas sample is in display space. Match the
		// linear albedo used for lighting and the standard held-item materials.
		ALBEDO = OUTPUT_IS_SRGB ? pow(tex.rgb, vec3(2.2)) : tex.rgb;
	} else {
		ALBEDO = pow(COLOR.rgb, vec3(2.2));
	}
	ROUGHNESS = 0.85;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float band = 0.35 + 0.30 * smoothstep(0.04, 0.09, facing)
		+ 0.35 * smoothstep(0.53, 0.58, facing);
	vec3 tone = mix(cool_shade, vec3(1.0), band);
	DIFFUSE_LIGHT += (LIGHT_COLOR / 3.14159265) * tone * band * ATTENUATION;
}
