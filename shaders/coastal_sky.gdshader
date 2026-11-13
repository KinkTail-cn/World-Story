shader_type sky;
render_mode disable_fog;

#include "coastal_palette.gdshaderinc"

// The visible palette uses a deliberate horizon haze rather than allowing
// depth fog to flatten the whole dome. Diving applies its own water tint.
uniform float underwater_mix = 0.0;

void sky() {
	vec3 light_direction = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	float radius = LIGHT0_ENABLED ? max(LIGHT0_SIZE * 0.5, 0.014) : 0.014;
	vec3 color = coastal_color(EYEDIR, light_direction, radius, LIGHT0_ENABLED, !AT_CUBEMAP_PASS);
	COLOR = mix(color, vec3(0.26, 0.55, 0.67), underwater_mix);
}
