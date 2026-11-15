shader_type canvas_item;
// Blick durch den Türspion: starke Fischaugen-Verzerrung, runder Ausschnitt, dunkler Rand, leichtes Korn.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float aspect = 1.777;
uniform float radius = 0.42;
uniform float time = 0.0;
uniform float darkness = 0.0;

float rand(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 c = UV - vec2(0.5);
	c.x *= aspect;
	float r = length(c);
	// Fischauge: in der Mitte vergrößert, zum Rand hin gestaucht
	float k = r / radius;
	vec2 dir = r > 0.0001 ? c / r : vec2(0.0);
	float warped = pow(clamp(k, 0.0, 1.0), 1.6) * radius * 1.05;
	vec2 uv = vec2(0.5) + vec2(dir.x / aspect, dir.y) * warped;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	// Glaslinse: Ränder dunkler und leicht gelblich
	float vig = smoothstep(1.0, 0.55, k);
	col *= mix(0.35, 1.0, vig);
	col *= vec3(1.0, 0.97, 0.88);
	col += (rand(UV * 900.0 + time) - 0.5) * 0.035;
	col *= 1.0 - darkness;
	// außerhalb des Kreises: die Tür von innen (fast schwarz)
	float ring = smoothstep(1.0, 0.97, k);
	COLOR = vec4(mix(vec3(0.015, 0.012, 0.01), col, ring), 1.0);
}
