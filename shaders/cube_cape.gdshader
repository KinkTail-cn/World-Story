shader_type spatial;
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float surface_roughness = 0.98;
uniform float surface_metallic = 0.0;
uniform float wind_strength = 0.0;
uniform float motion_scale = 1.0;
uniform float cape_length = 0.82;
uniform vec2 cape_uv_scale = vec2(1.0);
uniform vec2 cape_uv_offset = vec2(0.0);

// Integrate a changing direction along a ribbon segment. Each segment joins
// the next with a continuous tangent, so the hem curls instead of hinging.
vec2 cape_arc(float progress, float start_angle, float end_angle) {
	float turn = end_angle - start_angle;
	if (abs(turn) < 0.0001) {
		return vec2(sin(start_angle), cos(start_angle)) * progress;
	}
	float angle = start_angle + turn * progress;
	return vec2(cos(start_angle) - cos(angle), sin(angle) - sin(start_angle)) / turn;
}

void vertex() {
	// All vertices of one cube carry the same UV: translate the entire cube,
	// preserving its edge lengths, normals and orientation. The collar stays put.
	vec2 point = UV * cape_uv_scale + cape_uv_offset;
	float tail = clamp((point.y - 0.10) / 0.90, 0.0, 1.0);
	float side = point.x - 0.5;
	float ribbon_length = clamp(cape_length, 0.005, 1.6) * 0.90;
	float gust = sin(TIME * 1.7 + sin(TIME * 0.43) * 0.4);
	float roll = sin(TIME * (2.8 + wind_strength * 0.6) - 1.4 + side * 3.5);
	float flutter = sin(TIME * (6.5 + wind_strength * 1.4) + side * 6.0);
	float upper = clamp(0.15 + wind_strength * 0.50 + (0.08 + wind_strength * 0.06) * gust, -0.05, 1.45);
	float lower = clamp(0.20 + wind_strength * 0.90 + (0.25 + wind_strength * 0.10) * roll, -0.25, 2.15);
	float tip = lower + (0.28 + wind_strength * 0.12) * sin(TIME * (5.4 + wind_strength * 1.8) + side * 5.0) + flutter * 0.08;
	vec2 curve = 0.58 * cape_arc(clamp(tail / 0.58, 0.0, 1.0), 0.0, upper);
	curve += 0.27 * cape_arc(clamp((tail - 0.58) / 0.27, 0.0, 1.0), upper, lower);
	curve += 0.15 * cape_arc(clamp((tail - 0.85) / 0.15, 0.0, 1.0), lower, tip);
	float sway = sin(TIME * (1.9 + wind_strength * 0.35) - tail * 3.4);
	sway += sin(TIME * 4.1 - tail * 5.0) * 0.25;
	vec3 shift = vec3(ribbon_length * (0.04 + wind_strength * 0.035) * sway * pow(tail, 1.15), ribbon_length * (tail - curve.y), max(0.0, ribbon_length * curve.x));
	VERTEX += shift * motion_scale;
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
