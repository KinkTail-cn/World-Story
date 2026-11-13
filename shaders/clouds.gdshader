shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

#include "coastal_palette.gdshaderinc"

uniform vec3 sun_direction = vec3(0.4, 0.6, 0.6);
varying vec3 cloud_normal;
varying float cloud_distance;
varying vec3 cloud_position;

void vertex() {
	cloud_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	cloud_distance = length((MODEL_MATRIX[3].xyz - CAMERA_POSITION_WORLD).xz);
	cloud_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float top = smoothstep(-0.35, 0.8, cloud_normal.y);
	vec3 color = mix(vec3(0.79, 0.85, 0.89), vec3(0.98, 0.98, 0.95), top);
	float sunlight = pow(max(dot(cloud_normal, sun_direction), 0.0), 2.0);
	color = mix(color, vec3(1.0, 0.97, 0.89), sunlight * 0.22);
	vec3 sky = coastal_color(normalize(cloud_position - CAMERA_POSITION_WORLD), sun_direction, 0.014, true, true);
	float haze = max(1.0 - exp(-cloud_distance * 0.0012), smoothstep(165.0, 242.0, cloud_distance));
	ALBEDO = mix(color, sky, haze);
}
