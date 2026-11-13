// Shared by the background and distant cloud surfaces so clouds can dissolve
// into the exact same sky palette without transparency sorting or stippling.
uniform vec3 zenith_color = vec3(0.27, 0.49, 0.68);
uniform vec3 middle_color = vec3(0.48, 0.70, 0.82);
uniform vec3 horizon_color = vec3(0.77, 0.86, 0.89);
uniform vec3 sun_color = vec3(1.0, 0.95, 0.82);

float sky_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float sky_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	return mix(mix(sky_hash(cell), sky_hash(cell + vec2(1.0, 0.0)), local.x), mix(sky_hash(cell + vec2(0.0, 1.0)), sky_hash(cell + vec2(1.0)), local.x), local.y);
}

vec3 coastal_color(vec3 direction, vec3 light_direction, float sun_radius, bool with_sun, bool with_wisps) {
	float altitude = max(direction.y, 0.0);
	vec3 color = mix(horizon_color, middle_color, smoothstep(0.0, 0.32, altitude));
	color = mix(color, zenith_color, smoothstep(0.22, 1.0, altitude));
	if (direction.y < 0.0) {
		color = mix(horizon_color, vec3(0.48, 0.61, 0.65), smoothstep(0.0, 0.65, -direction.y));
	}
	if (with_sun && direction.y > 0.0) {
		float angle = acos(clamp(dot(direction, light_direction), -1.0, 1.0));
		float halo = exp(-angle * angle * 48.0) * 0.16;
		float inner_halo = exp(-angle * angle * 1800.0) * 0.15;
		color = mix(color, sun_color, halo + inner_halo);
		float disc = 1.0 - smoothstep(sun_radius * 0.80, sun_radius, angle);
		color = mix(color, sun_color, disc);
	}
	if (with_wisps && direction.y > 0.12) {
		vec2 p = direction.xz / max(direction.y, 0.18);
		p = mat2(vec2(0.92, 0.38), vec2(-0.38, 0.92)) * p;
		float wisps = sky_noise(p * vec2(2.2, 8.0));
		wisps += sky_noise(p * vec2(5.0, 18.0) + 13.0) * 0.35;
		float veil = smoothstep(0.78, 1.18, wisps) * smoothstep(0.12, 0.35, direction.y) * 0.09;
		color = mix(color, vec3(0.94, 0.96, 0.96), veil);
	}
	return mix(color, horizon_color, 0.08);
}
