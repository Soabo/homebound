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
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	if (enabled > 0.5) {
		int bi = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
		float d = (BAYER[bi] / 16.0 - 0.5) * dither_strength;
		c = floor(c * color_levels + d + 0.5) / color_levels;
		vec2 v = SCREEN_UV - 0.5;
		c *= 1.0 - dot(v, v) * vignette_strength * 1.6;
		float g = hash(cell + vec2(floor(TIME * 18.0) * 3.7, 0.0)) - 0.5;
		c += g * grain_strength;
	}
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
