shader_type spatial;
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = pow(base_color.rgb, vec3(2.2));
	ROUGHNESS = 0.8;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float band = 0.4 + 0.6 * smoothstep(0.45, 0.6, facing);
	vec3 shade = mix(vec3(0.72, 0.75, 0.88), vec3(1.0), band);
	DIFFUSE_LIGHT += (LIGHT_COLOR / 3.14159265) * shade * band * ATTENUATION;
}
