shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec3 deep_color : source_color = vec3(0.13, 0.36, 0.48);
uniform vec3 shallow_color : source_color = vec3(0.29, 0.54, 0.58);
uniform vec3 foam_color : source_color = vec3(0.72, 0.83, 0.84);
varying vec2 water_position;
varying vec3 world_normal;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 p = water_position;
	// 动态双层微波涟漪与浮沫浪纹
	float swell = sin(p.x * 0.35 + p.y * 0.22 + TIME * 0.45);
	float ripple = sin(p.y * 0.60 - p.x * 0.18 - TIME * 0.35 + swell * 0.6);
	float foam = smoothstep(0.72, 0.96, ripple);
	
	// 基础水体深度渐变
	vec3 water_col = mix(deep_color, shallow_color, 0.25 + 0.35 * sin(p.x * 0.1 + p.y * 0.1 + TIME * 0.2));
	water_col = mix(water_col, foam_color, foam * 0.18);
	
	ALBEDO = water_col;
	ROUGHNESS = 0.42;
	SPECULAR = 0.22;
	
	// 菲涅尔边缘反光效果：俯视时清澈见底，平视时反射海天微光
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	
	if (FRONT_FACING) {
		// 水面半透明清澈度：俯视透明度约 0.42，能清澈看清水底金黄沙石；平视略带反射 0.68
		ALPHA = mix(0.42, 0.68, fresnel) + foam * 0.12;
	} else {
		// 水下仰视水面
		ALPHA = 0.28;
	}
}
