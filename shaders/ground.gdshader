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
	// Pfützen: größer auf dem Weg, bei sehr nassem Boden auch kleine in Senken daneben
	float hollow = noise * 0.6 + big * 0.5;
	float puddle = smoothstep(0.55, 0.64, hollow) * m * smoothstep(0.3, 0.8, wetness);
	puddle = max(puddle, smoothstep(0.7, 0.76, hollow) * (1.0 - m) * smoothstep(0.7, 1.0, wetness) * 0.8);
	col *= mix(1.0, 0.58, wetness * 0.85);
	// Wasserfläche: dunkel, spiegelt flach einfallend den hellen Himmel (Fresnel)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 water = col * 0.3 + vec3(0.02, 0.025, 0.03) + vec3(0.32, 0.36, 0.42) * fres * 0.9;
	col = mix(col, water, puddle);
	ALBEDO = col;
	ROUGHNESS = mix(mix(1.0, 0.6, wetness), 0.04, puddle);
	SPECULAR = mix(0.5, 0.9, max(puddle, wetness * 0.3));
	METALLIC = 0.0;
}
