shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.42, 0.59, 0.37, 1.0);
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float wash = noise(world_pos.xz * 0.21) * 0.65 + noise(world_pos.xz * 0.67) * 0.35;
 float grain = noise(world_pos.xz * 24.0) - 0.5;
 vec3 dark = base_color.rgb * vec3(0.82,0.89,0.77);
 vec3 pale = base_color.rgb * 1.16 + vec3(0.055,0.035,0.008);
 ALBEDO = mix(dark,pale,smoothstep(0.1,0.85,wash)) + grain*0.027;
 ROUGHNESS = 0.97;
}
