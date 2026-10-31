shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 light_color : source_color = vec4(1.0, 0.84, 0.51, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.32;

void fragment() {
	// The side of the cone fades softly into the sky; the distant end never
	// forms a hard cap. Cylinder UV.y runs from the lamp to the far end.
	float rim = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.4);
	float start = smoothstep(0.0, 0.06, UV.y);
	float end = 1.0 - smoothstep(0.35, 1.0, UV.y);
	ALBEDO = light_color.rgb * 1.6;
	ALPHA = strength * rim * start * end;
}
