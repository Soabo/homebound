shader_type spatial;
// Gelände: Waldboden-Textur, auf Wegen Erde/Kies. Die Farbe kommt aus den Eckpunkten (Terrain.ground_color),
// der Alpha-Wert der Eckpunkte sagt, wie viel Weg hier ist (1 = kein Weg, 0 = mitten auf dem Weg).
// Nach Regen (globaler Wert wetness): Boden dunkler und feucht glänzend, auf Wegen bilden sich Pfützen.
// Laub- und Nadelstreu als zweites, grobes Muster.
// Spätherbst (globale Werte snow, frost aus WorldState): Schneedecke auf flachen Stellen – dünn noch fleckig, auf Wegen
// zertreten und grauer –, Raureif am Morgen als weißlicher Hauch mit Glitzern.
global uniform float wetness;
global uniform float snow;
global uniform float frost;

varying vec3 wnrm;
varying vec3 wpos;

// weiches Rauschen (Wert-Rauschen) für Schneeflecken – ohne Pixelkanten
float vhash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(vhash(i), vhash(i + vec2(1.0, 0.0)), u.x), mix(vhash(i + vec2(0.0, 1.0)), vhash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

uniform sampler2D grass_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D litter_tex : source_color, filter_nearest_mipmap, repeat_enable;
// Foto-Waldboden (nur klarer Grafikstil, Terrain setzt photo = 1): Moos mit Fichtennadeln (ambientCG Ground068, CC0).
// Er ersetzt die gezeichnete Textur dort, wo die Eckpunktfarbe Waldboden ist (Nähe zu floor_ref).
uniform float photo = 0.0;
uniform sampler2D floor_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float floor_meters = 2.6;        // so viele Meter misst eine Kachel des Fotos
uniform float floor_gain = 0.85;         // Helligkeit gegenüber der alten Textur
uniform vec3 floor_ref = vec3(0.11, 0.12, 0.06);   // Waldboden-Farbe aus Terrain.ground_color

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
	float fw = 0.0;
	vec3 fnrm = vec3(0.5, 0.5, 1.0);
	float frough = 1.0;
	if (photo > 0.5) {
		// zwei Maßstäbe, der zweite gedreht, großes Rauschen mischt – so sieht man keine Kachelwiederholung
		vec2 fuv = wpos.xz / floor_meters;
		vec2 ruv = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wpos.xz / (floor_meters * 1.7) + vec2(0.31, 0.77);
		float blend = smoothstep(0.3, 0.7, vnoise(wpos.xz * 0.11));
		vec3 f1 = texture(floor_tex, fuv).rgb;
		vec3 f2 = texture(floor_tex, ruv).rgb;
		vec3 photo_col = mix(f1, f2, blend * 0.6);
		// helle und dunkle Großflecken wie bisher (Eckpunktfarbe im Verhältnis zur Waldfarbe)
		vec3 tint = clamp(COLOR.rgb / floor_ref, vec3(0.6), vec3(1.4));
		fw = (1.0 - smoothstep(0.025, 0.075, distance(COLOR.rgb, floor_ref))) * (1.0 - m);
		col = mix(col, photo_col * tint * floor_gain, fw);
		fnrm = texture(floor_nrm, fuv).rgb;
		frough = texture(floor_rough, fuv).r;
	}
	// Pfützen: in Senken des Wegs (Rauschen), nur wenn nass
	// Pfützen: größer auf dem Weg, bei sehr nassem Boden auch kleine in Senken daneben
	float hollow = noise * 0.6 + big * 0.5;
	float puddle = smoothstep(0.55, 0.64, hollow) * m * smoothstep(0.3, 0.8, wetness);
	puddle = max(puddle, smoothstep(0.7, 0.76, hollow) * (1.0 - m) * smoothstep(0.7, 1.0, wetness) * 0.8);
	col *= mix(1.0, 0.58, wetness * 0.85);
	// Wasserfläche: dunkel, spiegelt flach einfallend den hellen Himmel (Fresnel)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 water = col * 0.3 + vec3(0.02, 0.025, 0.03) + vec3(0.32, 0.36, 0.42) * fres * 0.9;
	// Schnee: ab einer Decke von ~0,6 geschlossen, darunter Flecken (große Rauschmuster), nur auf flachem Boden
	float flat_ground = smoothstep(0.55, 0.85, wnrm.y);
	float patches = vnoise(wpos.xz * 0.18) * 0.6 + vnoise(wpos.xz * 0.9) * 0.3 + noise * 0.1;
	float cover = smoothstep(0.9 - snow * 1.6, 1.1 - snow * 1.6, patches) * flat_ground;
	cover *= mix(1.0, 0.7, m * smoothstep(0.3, 1.0, snow));   // Wege: zertreten, Erde schaut durch
	puddle *= 1.0 - cover;
	col = mix(col, water, puddle);
	vec3 snow_col = vec3(0.9, 0.92, 0.96) * (0.92 + litter.a * 0.1) * mix(1.0, 0.82, m);
	col = mix(col, snow_col, cover);
	// Raureif: weißlicher Hauch auf Gras und Streu (nicht unter Schnee), feines Glitzern
	float rime = frost * (1.0 - cover) * (0.55 + 0.45 * flat_ground) * mix(1.0, 0.5, m);
	vec3 rimed = col * 0.55 + vec3(0.36, 0.38, 0.42) * (0.8 + noise * 0.4);
	col = mix(col, rimed, rime * 0.55 * (0.5 + 0.5 * step(0.45, noise)));
	float glint = step(0.985, fract(sin(dot(floor(wpos.xz * 9.0), vec2(12.9898, 78.233))) * 43758.5453));
	ALBEDO = col;
	if (photo > 0.5) {
		NORMAL_MAP = fnrm;
		NORMAL_MAP_DEPTH = fw * (1.0 - cover) * (1.0 - puddle) * 1.2;
	}
	float base_rough = mix(1.0, frough, fw);
	ROUGHNESS = mix(mix(mix(base_rough, 0.6, wetness), 0.04, puddle), 0.75, max(cover, rime) * 0.7);
	SPECULAR = mix(0.5, 0.9, max(puddle, wetness * 0.3)) + glint * max(cover, rime) * 0.5;
	METALLIC = 0.0;
}
