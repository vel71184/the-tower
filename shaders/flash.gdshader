shader_type spatial;
// Drawn over a mesh for a moment: a hit (white) or a wind-up warning (red).
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = color.rgb * 0.75;
}
