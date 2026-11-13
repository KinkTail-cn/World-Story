shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, fog_disabled;

uniform vec3 deep_color : source_color = vec3(0.13, 0.36, 0.48);
uniform vec3 shallow_color : source_color = vec3(0.29, 0.54, 0.58);
uniform vec3 foam_color : source_color = vec3(0.72, 0.83, 0.84);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.77, 0.82);
uniform vec3 haze_color = vec3(0.77, 0.86, 0.89);
uniform vec3 sun_direction = vec3(0.4, 0.6, 0.6);
varying vec2 water_position;
varying vec3 world_normal;
varying float surface_height;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	surface_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec2 p = water_position;
	// 动态双层微波涟漪与浮沫浪纹
	float swell = sin(p.x * 0.35 + p.y * 0.22 + TIME * 0.45);
	float ripple = sin(p.y * 0.60 - p.x * 0.18 - TIME * 0.35 + swell * 0.6);
	float detail = 1.0 - smoothstep(45.0, 220.0, length(VERTEX));
	float foam = smoothstep(0.72, 0.96, ripple) * detail;
	
	// 基础水体深度渐变
	vec3 water_col = mix(deep_color, shallow_color, 0.35 + 0.12 * sin(p.x * 0.1 + p.y * 0.1 + TIME * 0.2) * detail);
	water_col = mix(water_col, foam_color, foam * 0.18);
	
	// 菲涅尔边缘反光效果：俯视时清澈见底，平视时反射海天微光
	bool above_surface = CAMERA_POSITION_WORLD.y >= surface_height;
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - vec3(water_position.x, surface_height, water_position.y));
	vec3 normal_world = normalize(world_normal);
	float fresnel = pow(1.0 - clamp(abs(dot(normal_world, to_camera)), 0.0, 1.0), 3.0);
	vec3 surface_color = mix(water_col, horizon_color, fresnel * 0.65);
	float horizon_haze = smoothstep(140.0, 650.0, length(VERTEX));
	float haze = above_surface ? horizon_haze : 1.0 - exp(-length(VERTEX) * 0.055);
	vec3 ripple_normal = normalize(normal_world + vec3(sin(p.x * 0.42 + p.y * 0.2 + TIME * 0.7), 0.0, cos(p.y * 0.38 - p.x * 0.15 - TIME * 0.6)) * 0.018 * detail);
	float glint = pow(max(dot(reflect(-normalize(sun_direction), ripple_normal), to_camera), 0.0), 80.0) * 0.045 * detail;
	surface_color += vec3(1.0, 0.96, 0.86) * (above_surface ? glint : 0.0);
	// Hand-painted water and the sky share a display-space horizon palette.
	ALBEDO = mix(surface_color, above_surface ? haze_color : vec3(0.26, 0.55, 0.67), haze);
	
	if (above_surface) {
		// 水面半透明清澈度：俯视透明度约 0.42，能清澈看清水底金黄沙石；平视略带反射 0.68
		ALPHA = mix(mix(0.42, 0.68, fresnel) + foam * 0.08, 1.0, horizon_haze);
	} else {
		// 水下仰视水面
		ALPHA = 0.28;
	}
}
