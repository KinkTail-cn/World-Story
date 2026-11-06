shader_type spatial;
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float surface_roughness = 0.9;
uniform float surface_metallic = 0.0;
uniform int motion_profile = 0;
uniform float motion_scale = 1.0;
uniform float wind_strength = 0.0;
uniform float motion_length = 0.3;
uniform vec2 motion_uv_scale = vec2(1.0);
uniform vec2 motion_uv_offset = vec2(0.0);
uniform bool horizontal_sheet = false;
uniform float outward_sign = 1.0;

void vertex() {
	// The motion coordinates are constant over all vertices of one cube.
	vec2 point = (horizontal_sheet ? UV2 : UV) * motion_uv_scale + motion_uv_offset;
	float free_end = pow(clamp((point.y - 0.12) / 0.88, 0.0, 1.0), 1.5);
	float extent = clamp(motion_length, 0.005, 0.8);
	float breeze = 0.45 + min(wind_strength, 1.65) * 0.55;
	float wave = sin(TIME * 2.1 - point.y * 3.0 + point.x * 1.1);
	vec3 shift = vec3(0.0);
	if (motion_profile == 2) { // a feather is held at its base
		wave = sin(TIME * 3.2 - point.y * 3.8);
		shift = vec3(wave * 0.09, 0.0, cos(TIME * 2.5 - point.y * 3.0) * 0.055) * extent * breeze;
	} else if (motion_profile == 3) { // a loose sheet held by the pen on its right
		free_end = pow(clamp(1.0 - point.x, 0.0, 1.0), 2.0);
		shift.y = (0.55 + 0.45 * sin(TIME * 2.4 - point.x * 2.5 + point.y)) * 0.010;
	} else {
		float flexibility = motion_profile == 1 ? 0.035 : 0.14;
		shift = vec3(wave * flexibility, 0.015 * sin(TIME * 2.0 - point.y), outward_sign * (0.5 + 0.5 * cos(TIME * 2.3 - point.y * 3.4)) * flexibility * 0.65) * extent * breeze;
	}
	VERTEX += shift * free_end * motion_scale;
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
