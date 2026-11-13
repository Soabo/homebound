shader_type spatial;
render_mode cull_disabled;
// Pflanzen im Wind: Gras, Farn, Büsche, Laubkronen und Nadel-Etagen wiegen sich.
// Wind kommt aus den globalen Werten (Wind-Knoten, scripts/world/wind.gd):
//   wind_strength 0..1, wind_dir (Richtung), wind_time (Uhr des Windes),
//   rustle = Ort + Stärke eines Raschelns (etwas bewegt sich im Gebüsch), wetness = nass vom Regen.
// Die Böen laufen als Wellen über den Wald – dieselbe Formel rechnet Wind.gust_at() für den Klang.

global uniform float wind_strength;
global uniform vec2 wind_dir;
global uniform float wind_time;
global uniform vec4 rustle;
global uniform float wetness;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool use_alpha = true;
uniform float alpha_cut = 0.5;
uniform bool triplanar = false;
uniform float tex_scale = 1.0;
// Ausschlag in Metern bei vollem Wind, ab welcher Höhe (lokal) voll, wie starr (1 = ganzes Teil bewegt sich gleich)
uniform float sway = 0.12;
uniform float height_ref = 1.0;
uniform float rigid = 0.0;
uniform float flutter = 0.03;

varying vec3 wpos;
varying vec3 wnrm;

float gust(vec2 p) {
	float a = sin(dot(p, wind_dir) * 0.045 - wind_time * 0.6);
	float b = sin(dot(p, vec2(-wind_dir.y, wind_dir.x)) * 0.021 + wind_time * 0.17);
	return clamp(0.5 + 0.38 * a + 0.22 * b, 0.0, 1.0);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = mix(clamp(VERTEX.y / height_ref, 0.0, 1.6), 1.0, rigid);
	float g = gust(origin.xz);
	float s = wind_strength * (0.3 + g * 1.1);
	float phase = dot(origin.xz, vec2(0.37, 0.71));
	vec2 side = vec2(-wind_dir.y, wind_dir.x);
	vec2 bend = wind_dir * s * (0.55 + 0.45 * sin(wind_time * 1.6 + phase));
	bend += side * s * 0.25 * sin(wind_time * 2.3 + phase * 1.7);
	// Rascheln: in der Nähe zittert und wackelt alles heftig
	float rd = distance(origin.xz, rustle.xz);
	float r = rustle.w * (1.0 - smoothstep(0.6, 3.2, rd)) * step(abs(origin.y - rustle.y), 6.0);
	bend += vec2(sin(wind_time * 21.0 + phase * 5.0), cos(wind_time * 17.0 + phase * 3.0)) * r * 0.5;
	vec3 off = vec3(bend.x, 0.0, bend.y) * sway * h;
	off += vec3(sin(wind_time * 9.0 + wp.x * 3.1), 0.0, cos(wind_time * 8.0 + wp.z * 2.7)) * flutter * (s + r) * h;
	off.y -= length(bend) * sway * h * 0.15;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
	wpos = wp;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec4 tex;
	if (triplanar) {
		vec3 n = abs(wnrm);
		n /= (n.x + n.y + n.z);
		vec3 p = wpos * tex_scale;
		tex = texture(albedo_tex, p.zy) * n.x + texture(albedo_tex, p.xz) * n.y + texture(albedo_tex, p.xy) * n.z;
	} else {
		tex = texture(albedo_tex, UV * tex_scale);
	}
	ALBEDO = tex.rgb * COLOR.rgb * tint.rgb * mix(1.0, 0.78, wetness);
	if (use_alpha) {
		ALPHA = tex.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
	ROUGHNESS = mix(1.0, 0.5, wetness);
	SPECULAR = mix(0.25, 0.5, wetness);
}
