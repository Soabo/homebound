shader_type spatial;
// Gelände: Waldboden-Textur, auf Wegen Erde/Kies. Die Farbe kommt aus den Eckpunkten (Terrain.ground_color),
// der Alpha-Wert der Eckpunkte sagt, wie viel Weg hier ist (1 = kein Weg, 0 = mitten auf dem Weg).
// Nach Regen (globaler Wert wetness): Boden dunkler und feucht glänzend, auf Wegen bilden sich Pfützen.
// Laub- und Nadelstreu als zweites, grobes Muster.
global uniform float wetness;

uniform sampler2D grass_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D litter_tex : source_color, filter_nearest_mipmap, repeat_enable;

void fragment() {
	vec3 grass = texture(grass_tex, UV).rgb;
	vec3 path = texture(path_tex, UV * 1.5).rgb;
	// Rand ausfransen: grobes Rauschen aus dem Alpha-Kanal der Wegtextur
	float noise = texture(path_tex, UV * 0.31).a;
	float big = texture(path_tex, UV * 0.07 + vec2(0.37, 0.11)).a;
	float amount = 1.0 - COLOR.a;
	float m = smoothstep(0.38, 0.62, amount + (noise - 0.5) * 0.55);
	// Streu (Laub, Nadeln, Zweige) fleckig auf dem Waldboden, nicht auf dem Weg
	vec4 litter = texture(litter_tex, UV * 1.3);
	float lm = smoothstep(0.45, 0.75, big) * litter.a * (1.0 - m);
	vec3 ground = mix(grass, litter.rgb * 1.6, lm * 0.7);
	vec3 col = COLOR.rgb * mix(ground, path, m);
	// Pfützen: in Senken des Wegs (Rauschen), nur wenn nass
	float puddle = smoothstep(0.62, 0.7, noise * 0.6 + big * 0.5) * m * smoothstep(0.35, 0.9, wetness);
	col *= mix(1.0, 0.58, wetness * 0.85);
	col = mix(col, col * 0.35 + vec3(0.02, 0.025, 0.03), puddle);
	ALBEDO = col;
	ROUGHNESS = mix(mix(1.0, 0.6, wetness), 0.04, puddle);
	SPECULAR = mix(0.5, 0.9, max(puddle, wetness * 0.3));
	METALLIC = 0.0;
}
