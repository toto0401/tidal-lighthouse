shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.956, 0.898, 0.788, 1.0);
varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xy + world_position.zy * vec2(0.71, 0.23);
	float broad = grain(p * 2.1);
	float speckle = grain(p * 22.0);
	ALBEDO = base_color.rgb * (0.955 + broad * 0.065 + speckle * 0.025);
	ROUGHNESS = 0.92;
}
