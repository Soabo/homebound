shader_type spatial;
// Prozedurales Bruchsteinmauerwerk mit Fugen, ausgerichtet nach der Flächennormale.

uniform vec3 base_color : source_color = vec3(0.42, 0.41, 0.39);
uniform vec3 mortar_color : source_color = vec3(0.22, 0.21, 0.20);
uniform float stone_size = 0.32;

varying vec3 world_pos;
varying vec3 world_normal;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y > n.x && n.y > n.z) {
		uv = world_pos.xz;
	} else if (n.x > n.z) {
		uv = world_pos.zy;
	} else {
		uv = world_pos.xy;
	}
	uv /= vec2(stone_size * 1.6, stone_size);
	uv.x += floor(uv.y) * 0.5;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float edge = min(min(f.x, 1.0 - f.x) * 1.6, min(f.y, 1.0 - f.y));
	float stone = smoothstep(0.03, 0.09, edge);
	float tone = 0.72 + 0.4 * hash2(cell);
	vec3 col = mix(mortar_color, base_color * tone, stone);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
