shader_type spatial;
render_mode cull_back, specular_disabled;

// Recolours any Kenney model by colour family. Each swap names a reference colour from
// Kenney's shared palette ("from") and a new colour ("to"). Every texel of the same family
// (close in hue and saturation) takes the new colour, keeping its own light or dark shade,
// so wood grain and stone gradients survive. Set by models.gd recolor().

const int MAX_SWAPS = 8;

// Sampled as stored (sRGB), so it compares directly with palette colours; converted to
// linear at the end.
uniform sampler2D albedo_texture : filter_nearest_mipmap, repeat_disable;
uniform int swap_count = 0;
uniform vec3 swap_from[MAX_SWAPS];
uniform vec3 swap_to[MAX_SWAPS];
uniform float hue_tolerance = 0.055;
uniform float sat_tolerance = 0.3;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec3 c = texture(albedo_texture, UV).rgb;
	vec3 h = rgb2hsv(c);
	for (int i = 0; i < MAX_SWAPS; i++) {
		if (i >= swap_count) {
			break;
		}
		vec3 ref = rgb2hsv(swap_from[i]);
		float dh = abs(h.x - ref.x);
		dh = min(dh, 1.0 - dh);
		if (dh < hue_tolerance && abs(h.y - ref.y) < sat_tolerance && h.z > 0.08) {
			c = clamp(swap_to[i] * (h.z / max(ref.z, 0.01)), 0.0, 1.0);
			break;
		}
	}
	ALBEDO = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	ROUGHNESS = 0.9;
}
