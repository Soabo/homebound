shader_type spatial;
render_mode cull_back;
// Schnee und Raureif auf Dächern, Felsen, liegenden Stämmen (als zweiter Durchgang, next_pass, über dem eigentlichen Material).
// Nur nach oben zeigende Flächen; dünne Decken fleckig (Pixelraster), volle Decken geschlossen.
global uniform float snow;
global uniform float frost;
uniform float hold = 1.0;

varying vec3 wn;
varying vec3 wp;

void vertex() {
	wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * 0.015;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 cell = floor(wp * 6.0);
	float n = hash(cell);
	float big = hash(floor(wp * 1.3));
	float up = smoothstep(0.35, 0.8, wn.y);
	float cover = snow * hold * up;
	float rime = frost * 0.3 * smoothstep(0.1, 0.6, wn.y);
	// stochastische Deckung: wo der Zufall unter der Deckung liegt, liegt Schnee
	bool snowy = n * 0.6 + big * 0.4 < cover * 1.25;
	bool rimy = !snowy && n < rime * 0.8;
	if (!snowy && !rimy) {
		discard;
	}
	ALBEDO = snowy ? vec3(0.9, 0.92, 0.96) * (0.94 + n * 0.08) : vec3(0.78, 0.82, 0.88);
	ROUGHNESS = 0.8;
	SPECULAR = 0.4 + step(0.97, n) * 0.4;
}
