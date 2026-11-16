shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float side = 1.0 - smoothstep(0.15, 0.85, UV.x);
	float bottom = smoothstep(0.58, 1.0, UV.y);
	float edge = smoothstep(0.25, 0.78, distance(UV, vec2(0.56, 0.45)));
	COLOR = vec4(0.025, 0.085, 0.11, clamp(0.14 + side * 0.64 + bottom * 0.26 + edge * 0.12, 0.0, 0.88));
}
