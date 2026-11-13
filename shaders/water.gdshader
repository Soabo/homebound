shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
// Bach und Seen: fließt (Bach) bzw. kräuselt sich im Wind (Seen), spiegelt den Himmel (je flacher der Blick,
// desto mehr), glitzert in der Sonne, Schaum an den Ufern des Bachs, Ringe von Regentropfen.
global uniform float wind_strength;
global uniform vec2 wind_dir;
global uniform float wind_time;
global uniform float wetness;

uniform sampler2D water_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 color : source_color = vec4(0.65, 0.78, 0.72, 0.85);
uniform float flow = 0.0;          // Fließgeschwindigkeit (0 = See)
uniform float rain = 0.0;          // Regen 0..1 (Ringe)

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	vec2 drift = flow > 0.0 ? vec2(0.0, -wind_time * flow) : wind_dir * wind_time * 0.02 * (0.3 + wind_strength);
	vec4 a = texture(water_tex, uv + drift);
	vec4 b = texture(water_tex, uv * 1.7 + drift * 1.4 + vec2(0.31, 0.17));
	float l = dot(a.rgb + b.rgb, vec3(0.33)) * 0.5;
	// Wellen-Normale aus der Helligkeit der beiden Schichten
	vec2 dn = vec2(a.r - b.g, a.g - b.r) * (0.35 + wind_strength * 0.4 + flow * 2.0);
	// Regentropfen: kleine Ringe, die aufgehen
	if (rain > 0.01) {
		vec2 cell = floor(uv * 6.0);
		vec2 f = fract(uv * 6.0) - 0.5 - (vec2(h2(cell), h2(cell + 7.0)) - 0.5) * 0.6;
		float t = fract(wind_time * 0.9 + h2(cell + 3.0));
		float ring = smoothstep(0.04, 0.0, abs(length(f) - t * 0.45)) * (1.0 - t);
		dn += f * ring * 2.0 * rain;
	}
	NORMAL = normalize(NORMAL + (TANGENT * dn.x + BINORMAL * dn.y) * 0.6);
	// Schaum am Bachufer (Farbe der Eckpunkte: Alpha = Nähe zum Ufer)
	float foam = flow > 0.0 ? smoothstep(0.55, 1.0, COLOR.a + (l - 0.5) * 0.6) : 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(color.rgb * (0.55 + l * 0.6), vec3(0.85, 0.9, 0.9), foam * 0.7);
	ALPHA = clamp(color.a * 0.85 + fres * 0.25 + foam * 0.3, 0.0, 1.0);
	ROUGHNESS = mix(0.06, 0.35, foam);
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
