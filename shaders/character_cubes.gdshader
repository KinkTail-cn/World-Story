shader_type spatial;
render_mode specular_disabled;

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.8;
}

void light() {
	float band = 0.4 + 0.6 * smoothstep(0.45, 0.6, dot(NORMAL, LIGHT));
	vec3 shade = mix(vec3(0.72, 0.75, 0.88), vec3(1.0), band);
	DIFFUSE_LIGHT += (LIGHT_COLOR / 3.14159265) * shade * band * ATTENUATION;
}
