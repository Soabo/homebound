shader_type spatial;
// Gelände: Waldboden-Textur, auf Wegen Erde/Kies. Die Farbe kommt aus den Eckpunkten (Terrain.ground_color),
// der Alpha-Wert der Eckpunkte sagt, wie viel Weg hier ist (1 = kein Weg, 0 = mitten auf dem Weg).
uniform sampler2D grass_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_nearest_mipmap, repeat_enable;

void fragment() {
	vec3 grass = texture(grass_tex, UV).rgb;
	vec3 path = texture(path_tex, UV * 1.5).rgb;
	// Rand ausfransen: grobes Rauschen aus dem Alpha-Kanal der Wegtextur
	float noise = texture(path_tex, UV * 0.31).a;
	float amount = 1.0 - COLOR.a;
	float m = smoothstep(0.38, 0.62, amount + (noise - 0.5) * 0.55);
	ALBEDO = COLOR.rgb * mix(grass, path, m);
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
}
