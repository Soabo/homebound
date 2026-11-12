shader_type canvas_item;
// Überwachungsmonitor: grünliches Schwarzweiß, Zeilen, Rauschen, Störungen.

uniform float glitch = 0.0;
uniform float no_signal = 0.0;
uniform float noise_amount = 0.08;
// 1 = kein Strom: Bild bleibt schwarz (kein Störbild)
uniform float dark = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = floor(TIME * 24.0);
	// Zeilenversatz bei Störungen
	float line = floor(uv.y * 120.0);
	uv.x += (hash(vec2(line, t)) - 0.5) * 0.08 * glitch;
	uv.y += sin(TIME * 40.0) * 0.004 * glitch;
	vec3 c = texture(TEXTURE, uv).rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	lum = pow(lum, 0.8) * 1.25;
	vec3 col = vec3(lum * 0.85, lum * 1.0, lum * 0.8);
	float n = hash(floor(UV * vec2(320.0, 240.0)) + t);
	col += (n - 0.5) * (noise_amount + glitch * 0.6);
	col *= 0.85 + 0.15 * sin(UV.y * 480.0);
	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * 1.2;
	col = mix(col, vec3(n * 0.6), clamp(glitch * 0.7 + no_signal, 0.0, 1.0));
	col = mix(col, vec3(0.0), dark);
	COLOR = vec4(col, 1.0);
}
