shader_type spatial;
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float surface_roughness = 0.98;
uniform float surface_metallic = 0.0;
uniform float wind_strength = 0.0;
uniform float motion_scale = 1.0;
uniform vec2 cape_uv_scale = vec2(1.0);
uniform vec2 cape_uv_offset = vec2(0.0);

void vertex() {
	// All vertices of one cube carry the same UV: translate the entire cube,
	// preserving its edge lengths, normals and orientation. The collar stays put.
	vec2 point = UV * cape_uv_scale + cape_uv_offset;
	float tail = pow(clamp((point.y - 0.10) / 0.90, 0.0, 1.0), 1.35);
	float wave = sin(TIME * (3.4 + wind_strength * 2.0) - point.y * 5.0 + point.x * 1.4);
	float flutter = sin(TIME * 7.2 - point.y * 9.0 + point.x * 3.0) * 0.25;
	vec3 shift = vec3(
		sin(TIME * 2.4 - point.y * 3.0) * (0.008 + wind_strength * 0.025),
		wind_strength * (0.10 + wave * 0.015),
		0.02 + wind_strength * 0.36 + (wave + flutter) * (0.012 + wind_strength * 0.035)
	);
	VERTEX += shift * tail * motion_scale;
}

void fragment() {
	ALBEDO = pow(base_color.rgb, vec3(2.2));
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
}

void light() {
	float band = 0.4 + 0.6 * smoothstep(0.45, 0.6, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += (LIGHT_COLOR / 3.14159265) * mix(vec3(0.72, 0.75, 0.88), vec3(1.0), band) * band * ATTENUATION;
}
