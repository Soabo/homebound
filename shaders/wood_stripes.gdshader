shader_type spatial;
// Prozedurales Holz: Balken/Bretter als Streifen in Weltkoordinaten.
// axis: 0 = Streifen wechseln entlang X, 1 = entlang Y (liegende Balken), 2 = entlang Z

uniform vec3 base_color : source_color = vec3(0.45, 0.30, 0.18);
uniform int axis = 1;
uniform float stripe_size = 0.28;
uniform float groove = 0.12;
uniform float variation = 0.22;
uniform float roughness_value = 0.85;

varying vec3 world_pos;

float hash(float n) {
	return fract(sin(n * 127.1 + 0.3) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float c = axis == 0 ? world_pos.x : (axis == 1 ? world_pos.y : world_pos.z);
	float along = axis == 1 ? (world_pos.x + world_pos.z) : (axis == 0 ? world_pos.z + world_pos.y : world_pos.x + world_pos.y);
	float row = floor(c / stripe_size);
	float t = fract(c / stripe_size);
	float edge = smoothstep(0.0, groove, t) * smoothstep(1.0, 1.0 - groove, t);
	float tone = 1.0 + (hash(row) - 0.5) * variation;
	float grain = sin(along * 9.0 + hash(row + 7.0) * 20.0) * 0.05 + sin(along * 37.0 + row * 3.0) * 0.025;
	vec3 col = base_color * tone * (0.5 + 0.5 * edge) * (1.0 + grain);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
