shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.784, 0.373, 0.533, 1.0);
uniform float wind_strength = 0.0;
uniform vec4 trim_color : source_color = vec4(0.93, 0.80, 0.52, 1.0);
uniform int emblem = 0;

float star_mark(vec2 point, vec2 center, float scale) {
	vec2 p = abs((point - center) / scale);
	return 1.0 - smoothstep(0.85, 1.0, min(p.x * 3.5 + p.y, p.x + p.y * 3.5));
}

void vertex() {
	// tail 控制顶点受力权重：领口 (UV.y = 0) 稳固不移，下摆末梢 (UV.y = 1) 极为自由灵动
	float tail = pow(UV.y, 1.35);
	
	// 复合风阻动力学波形：
	// 1. 低频宏观气流主波浪：整体随风浪卷，波长宽阔
	float main_wave = sin(TIME * (3.8 + wind_strength * 3.2) - UV.y * 6.2 + (UV.x - 0.5) * 2.2);
	// 2. 高频微观末梢颤振波：模拟轻盈丝绸在疾风中的急速细微翻飞
	float flutter = sin(TIME * (8.2 + wind_strength * 5.5) - UV.y * 13.5 + UV.x * 4.8) * 0.45;
	// 3. 次级扭曲交叉波：增加布料左右非对称的自然呼吸感
	float cross_wave = cos(TIME * 2.6 - UV.y * 4.2 - UV.x * 3.0) * 0.25;
	
	float total_wave = (main_wave + flutter + cross_wave) * (0.025 + wind_strength * 0.11);
	
	// Z轴后扬与波浪：随着奔跑速度激增，披风优美大幅向后舒展掠飞
	VERTEX.z += tail * (0.035 + wind_strength * 0.72 + total_wave);
	
	// X轴横向摆动与风阻侧向展开：跑动时气流使披风两侧轻微展翼
	float wing_spread = (UV.x - 0.5) * tail * wind_strength * 0.18;
	float lateral_sway = sin(TIME * 3.6 - UV.y * 4.8) * (0.015 + wind_strength * 0.055);
	VERTEX.x += wing_spread + tail * lateral_sway;
	
	// Y轴垂直托升与起伏：奔跑时高速气流在披风下方产生空气动压托力，使下摆飘扬抬升
	float lift = tail * (wind_strength * 0.32 + (main_wave * 0.5 + flutter * 0.25) * wind_strength * 0.08);
	VERTEX.y += lift;
}

void fragment() {
	// 边缘细腻滚边（上下金丝边饰）
	float hem = step(0.95, UV.y) + step(UV.x, 0.035) + step(0.965, UV.x);
	vec3 gold_trim = trim_color.rgb;
	vec3 tint = mix(base_color.rgb, gold_trim, min(hem, 1.0) * 0.75);
	float mark = 0.0;
	if (emblem == 1) {
		vec2 p = abs(UV - vec2(0.5, 0.34));
		mark = 1.0 - smoothstep(0.08, 0.095, p.x * 0.7 + p.y);
	} else if (emblem == 2) {
		float upright = step(abs(UV.x - 0.5), 0.045) * step(0.23, UV.y) * step(UV.y, 0.65);
		float crossbar = step(abs(UV.x - 0.5), 0.19) * step(abs(UV.y - 0.35), 0.04);
		mark = max(upright, crossbar);
	} else if (emblem == 3) {
		mark = max(star_mark(UV, vec2(0.5, 0.30), 0.13), star_mark(UV, vec2(0.28, 0.57), 0.065));
		mark = max(mark, star_mark(UV, vec2(0.73, 0.65), 0.085));
	}
	tint = mix(tint, gold_trim, mark * 0.82);
	
	// 微妙的丝绸高光与布料质感
	ALBEDO = pow(tint, vec3(2.2));
	ROUGHNESS = 0.65;
	SPECULAR = 0.25;
	
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	// 柔和的布料双向透光感（两面立体阴影明暗）
	float band = 0.45 + 0.55 * smoothstep(0.35, 0.65, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += (LIGHT_COLOR / 3.14159265) * mix(vec3(0.75, 0.78, 0.90), vec3(1.0), band) * band * ATTENUATION;
}
