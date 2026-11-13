shader_type canvas_item;
// Retro-Bildfilter: grobe Pixel, begrenzte Farbstufen mit Bayer-Dithering,
// Vignette und Filmkorn. Liegt als Vollbild-Ebene über der 3D-Welt, unter dem HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 3.0;
uniform float color_levels = 56.0;
uniform float dither_strength = 0.45;
uniform float vignette_strength = 0.3;
uniform float grain_strength = 0.018;
uniform float enabled = 1.0;
// Blick der Kreatur ins Hirn (0 = nichts, 1 = volle Stärke): Wabern, Doppelbilder, Farbsäume, Rot und Dunkel
uniform float mind = 0.0;
// Farbabstimmung je Tageszeit (DayNightEnvironment): Farbe multiplizieren, Schatten anheben, Sättigung, Kontrast
uniform vec3 grade_tint = vec3(1.0);
uniform vec3 grade_lift = vec3(0.0);
uniform float grade_sat = 1.0;
uniform float grade_contrast = 1.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	if (enabled > 0.5) {
		vec2 px = SCREEN_PIXEL_SIZE * pixel_size;
		uv = (floor(SCREEN_UV / px) + 0.5) * px;
	}
	vec3 c;
	if (mind > 0.001) {
		float m = mind * mind;
		// Wabern: das Bild schwimmt in Wellen
		vec2 w = vec2(sin(SCREEN_UV.y * 18.0 + TIME * 6.0), cos(SCREEN_UV.x * 14.0 + TIME * 4.7)) * 0.012 * m;
		w += vec2(sin(TIME * 23.0), cos(TIME * 19.0)) * 0.004 * m * step(0.8, fract(TIME * 0.9));
		vec2 u = uv + w;
		// Farbsäume und ein nachziehendes Doppelbild
		float ca = 0.012 * m + 0.002;
		vec2 dir = normalize(SCREEN_UV - 0.5 + vec2(0.0001));
		c.r = textureLod(screen_tex, u + dir * ca, 0.0).r;
		c.g = textureLod(screen_tex, u, 0.0).g;
		c.b = textureLod(screen_tex, u - dir * ca, 0.0).b;
		vec3 ghost = textureLod(screen_tex, u + vec2(sin(TIME * 2.3), cos(TIME * 1.7)) * 0.03 * m, 0.0).rgb;
		c = mix(c, ghost, 0.35 * m);
	} else {
		c = textureLod(screen_tex, uv, 0.0).rgb;
	}
	// Farbabstimmung wie bei einem Film
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, grade_sat);
	c = (c - 0.5) * grade_contrast + 0.5;
	c = c * grade_tint + grade_lift * (1.0 - clamp(lum * 2.0, 0.0, 1.0));
	c = max(c, vec3(0.0));
	if (enabled > 0.5) {
		int bi = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
		float d = (BAYER[bi] / 16.0 - 0.5) * dither_strength;
		c = floor(c * color_levels + d + 0.5) / color_levels;
		vec2 v = SCREEN_UV - 0.5;
		c *= 1.0 - dot(v, v) * vignette_strength * 1.6;
		float g = hash(cell + vec2(floor(TIME * 18.0) * 3.7, 0.0)) - 0.5;
		c += g * grain_strength;
	}
	if (mind > 0.001) {
		float m = mind;
		vec2 v2 = SCREEN_UV - 0.5;
		float edge = clamp(dot(v2, v2) * 3.2, 0.0, 1.0);
		// Rand wird dunkel und blutrot, das Bild pulsiert
		float pulse = 0.5 + 0.5 * sin(TIME * (5.0 + m * 6.0));
		c = mix(c, c * vec3(1.15, 0.35, 0.35), m * 0.55);
		c *= 1.0 - edge * m * (0.6 + 0.3 * pulse);
		// Rauschen und kurze Aussetzer
		float n = hash(floor(FRAGCOORD.xy / 2.0) + vec2(TIME * 61.0, TIME * 17.0));
		c += (n - 0.5) * 0.25 * m;
		c *= 1.0 - step(0.97, fract(TIME * 1.3 + n * 0.02)) * m * 0.7;
	}
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
