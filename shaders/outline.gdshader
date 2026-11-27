shader_type spatial;
// Thin dark outline: the mesh drawn again slightly larger, back faces only (an "inverted hull").
// Used as a material overlay on characters and things in the world.
render_mode unshaded, cull_front, depth_draw_opaque, skip_vertex_transform;

uniform vec4 color : source_color = vec4(0.09, 0.07, 0.06, 1.0);
// World units. Kept small: a line, not a cartoon border.
uniform float width = 0.014;

void vertex() {
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz + n * width;
	NORMAL = n;
}

void fragment() {
	ALBEDO = color.rgb;
}
