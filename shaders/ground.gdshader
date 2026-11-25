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
// Foto-Boden (nur klarer Grafikstil, Terrain setzt photo = 1). Sechs Lagen in einem Texturstapel (assets/textures/ground):
// 0 Waldboden (Moos + Fichtennadeln), 1 Boden/Wiese, 2 Fels, 3 Bachbett-Kiesel, 4 Weg (Schotter), 5 Schnee.
// Lagen 1–5 sind auf mittlere Helligkeit gebracht und werden wie die alten Texturen mit der Eckpunktfarbe getönt.
uniform float photo = 0.0;
uniform sampler2DArray photo_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray photo_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 layer_meters = vec4(2.6, 3.0, 4.0, 1.6);   // Kachelgröße in m: Waldboden, Boden, Fels, Bachbett
uniform vec2 layer_meters2 = vec2(2.2, 2.5);            // Weg, Schnee
uniform float floor_gain = 0.85;         // Helligkeit Waldboden gegenüber der alten Textur
uniform float layer_gain = 1.05;         // Helligkeit der übrigen Lagen
uniform vec3 floor_ref = vec3(0.11, 0.12, 0.06);   // Waldboden-Farbe aus Terrain.ground_color
uniform vec3 bed_ref = vec3(0.22, 0.2, 0.16);      // Bachbett-Farbe aus Terrain.ground_color

// Eine Lage ohne sichtbare Kachelwiederholung: zwei Maßstäbe, der zweite gedreht, großes Rauschen mischt.
vec3 layer_col(float i, float meters, vec2 p, float blend) {
	vec3 a = texture(photo_col, vec3(p / meters, i)).rgb;
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p / (meters * 1.7) + vec2(0.31, 0.77);
	vec3 b = texture(photo_col, vec3(q, i)).rgb;
	return mix(a, b, blend * 0.6);
}
vec3 layer_nrm(float i, float meters, vec2 p) {
	return texture(photo_nrm, vec3(p / meters, i)).rgb;
}

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
	vec3 snow_tex = vec3(1.0);
	vec3 snow_nrm = vec3(0.5, 0.5, 1.0);
	if (photo > 0.5) {
		vec2 p = wpos.xz;
		float blend = smoothstep(0.3, 0.7, vnoise(p * 0.11));
		vec3 c = COLOR.rgb;
		// Zonen aus der Eckpunktfarbe: Fels (grau, hell), Bachbett, Waldboden, sonst Boden/Wiese
		float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
		float rock = (1.0 - smoothstep(0.03, 0.07, sat)) * smoothstep(0.24, 0.32, (c.r + c.g + c.b) / 3.0);
		float bed = (1.0 - smoothstep(0.02, 0.05, distance(c, bed_ref))) * (1.0 - rock);
		fw = (1.0 - smoothstep(0.025, 0.075, distance(c, floor_ref))) * (1.0 - rock) * (1.0 - bed);
		float meadow = 1.0 - rock - bed - fw;
		vec3 detail = layer_col(1.0, layer_meters.y, p, blend) * meadow
				+ layer_col(2.0, layer_meters.z, p, blend) * rock
				+ layer_col(3.0, layer_meters.w, p, blend) * bed;
		vec3 path_ph = layer_col(4.0, layer_meters2.x, p, blend);
		col = c * mix(detail * layer_gain, path_ph * layer_gain, m);
		// Waldboden: eigenes Foto, nur getönt (Großflecken), wie zuvor
		vec3 tint = clamp(c / floor_ref, vec3(0.6), vec3(1.4));
		col = mix(col, layer_col(0.0, layer_meters.x, p, blend) * tint * floor_gain, fw * (1.0 - m));
		vec3 n = layer_nrm(1.0, layer_meters.y, p) * meadow + layer_nrm(2.0, layer_meters.z, p) * rock
				+ layer_nrm(3.0, layer_meters.w, p) * bed + layer_nrm(0.0, layer_meters.x, p) * fw;
		fnrm = mix(n, layer_nrm(4.0, layer_meters2.x, p), m);
		frough = mix(0.97 * meadow + 0.85 * rock + 0.8 * bed + 0.95 * fw, 0.92, m);
		fw = 1.0;   // ab hier: Stärke der Normalen (alle Lagen haben welche)
		snow_tex = layer_col(5.0, layer_meters2.y, p, blend);
		snow_nrm = layer_nrm(5.0, layer_meters2.y, p);
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
	vec3 snow_col = vec3(0.9, 0.92, 0.96) * (0.92 + litter.a * 0.1) * mix(1.0, 0.82, m) * mix(vec3(1.0), snow_tex / 0.93, photo);
	col = mix(col, snow_col, cover);
	// Raureif: weißlicher Hauch auf Gras und Streu (nicht unter Schnee), feines Glitzern
	float rime = frost * (1.0 - cover) * (0.55 + 0.45 * flat_ground) * mix(1.0, 0.5, m);
	vec3 rimed = col * 0.55 + vec3(0.36, 0.38, 0.42) * (0.8 + noise * 0.4);
	col = mix(col, rimed, rime * 0.55 * (0.5 + 0.5 * step(0.45, noise)));
	float glint = step(0.985, fract(sin(dot(floor(wpos.xz * 9.0), vec2(12.9898, 78.233))) * 43758.5453));
	ALBEDO = col;
	if (photo > 0.5) {
		NORMAL_MAP = mix(fnrm, snow_nrm, cover);
		NORMAL_MAP_DEPTH = (1.0 - puddle) * mix(1.1, 0.8, cover);
	}
	float base_rough = mix(1.0, frough, fw);
	ROUGHNESS = mix(mix(mix(base_rough, 0.6, wetness), 0.04, puddle), 0.75, max(cover, rime) * 0.7);
	SPECULAR = mix(0.5, 0.9, max(puddle, wetness * 0.3)) + glint * max(cover, rime) * 0.5;
	METALLIC = 0.0;
}
