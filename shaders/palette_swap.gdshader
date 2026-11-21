shader_type spatial;
render_mode cull_back, specular_disabled;

// Recolours a Kenney colormap model by moving UVs from one palette colour to another.
// Each colour is a light/dark pair of cells in the shared colormap texture, so a swap
// keeps the model's shading. Set by scripts/characters/character_model.gd.

const int MAX_SWAPS = 12;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform int swap_count = 0;
uniform vec4 swap_from[MAX_SWAPS]; // UV rect of the source colour: x0, y0, x1, y1
uniform vec2 swap_by[MAX_SWAPS];   // UV offset to the target colour
uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	for (int i = 0; i < MAX_SWAPS; i++) {
		if (i >= swap_count) {
			break;
		}
		vec4 r = swap_from[i];
		if (UV.x >= r.x && UV.x < r.z && UV.y >= r.y && UV.y < r.w) {
			UV += swap_by[i];
			break;
		}
	}
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * tint.rgb;
	ROUGHNESS = 0.9;
}
