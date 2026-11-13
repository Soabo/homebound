shader_type sky;
// Himmel (DayNightEnvironment): Farbverlauf, Sonne, großer Mond mit Kratern, Mondhof und Lichtsaum,
// Sterne (funkeln), Milchstraße, ziehende Wolken (vom Wind getrieben, vom Mond beleuchtet),
// Blitze im Gewitter und Wetterleuchten am Horizont.

global uniform vec2 wind_dir;
global uniform float wind_time;

uniform vec3 top_color : source_color = vec3(0.24, 0.42, 0.7);
uniform vec3 horizon_color : source_color = vec3(0.66, 0.72, 0.78);
uniform vec3 ground_horizon : source_color = vec3(0.4, 0.4, 0.4);
uniform vec3 ground_bottom : source_color = vec3(0.1, 0.1, 0.1);
uniform float energy = 1.0;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_vis = 1.0;

uniform vec3 moon_dir = vec3(0.0, 0.5, -0.8);
uniform float moon_vis = 0.0;          // 0 = nicht zu sehen, 1 = voll
uniform float moon_size = 0.065;       // Winkelradius (rad) – größer als echt, damit er beeindruckt
uniform vec3 moon_tint : source_color = vec3(0.95, 0.97, 1.0);
uniform float moon_phase = 0.2;        // 0 = Vollmond, 1 = Halbmond (Schattenseite)

uniform float night = 0.0;             // 0 = Tag, 1 = Nacht (Sterne)
uniform float clouds = 0.3;            // Bewölkung 0..1
uniform vec3 cloud_day : source_color = vec3(0.9, 0.9, 0.92);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float flash = 0.0;             // Blitz 0..1
uniform vec3 flash_dir = vec3(1.0, 0.2, 0.0);
uniform float alien = 0.0;             // fremder Schimmer am Horizont (Terraforming)

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float cloud_at(vec3 d) {
	if (d.y < 0.0) return 0.0;
	vec2 uv = d.xz / (d.y + 0.12) * 0.22 + wind_dir * wind_time * 0.004;
	float n = texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.7 + vec2(0.3, 0.7)).r * 0.35;
	float c = smoothstep(1.0 - clouds * 0.95, 1.05 - clouds * 0.55, n + clouds * 0.25);
	return c * smoothstep(0.0, 0.12, d.y);
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col;
	if (y >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(y, 0.0, 1.0), 0.55));
	} else {
		col = mix(ground_horizon, ground_bottom, clamp(-y * 3.0, 0.0, 1.0)) * 0.6;
	}
	col *= energy;
	// fremder grünlicher Schimmer am Horizont
	col += vec3(0.04, 0.12, 0.06) * alien * exp(-abs(y) * 10.0) * night;
	// Sonne
	float sd = dot(d, normalize(sun_dir));
	col += sun_color * sun_vis * (smoothstep(0.9992, 0.9996, sd) * 12.0 + pow(max(sd, 0.0), 220.0) * 1.2 + pow(max(sd, 0.0), 8.0) * 0.12);

	if (!AT_CUBEMAP_PASS) {
		// Sterne und Milchstraße
		if (night > 0.01 && y > -0.02) {
			vec3 g = floor(d * 260.0);
			float h = hash3(g);
			float star = step(0.9965, h);
			float tw = 0.6 + 0.4 * sin(TIME * (2.0 + h * 9.0) + h * 40.0);
			float bright = (h - 0.9965) / 0.0035;
			vec3 scol = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), fract(h * 91.0));
			col += scol * star * tw * (0.35 + bright * 1.6) * night * night * night * smoothstep(-0.02, 0.15, y);
			// Milchstraße: schräges Band mit Staubwolken
			vec3 band_n = normalize(vec3(0.35, 0.25, 0.9));
			float bd = abs(dot(d, band_n));
			float mw = exp(-bd * bd * 40.0);
			float dust = texture(cloud_noise, vec2(atan(d.x, d.z) * 0.8, d.y * 1.5) + vec2(0.37, 0.11)).r;
			float fine = step(0.985, hash3(floor(d * 520.0)));
			col += vec3(0.32, 0.34, 0.42) * mw * (0.25 + dust * 0.75) * night * night * night * 0.35 * smoothstep(0.0, 0.25, y);
			col += vec3(0.6, 0.65, 0.8) * fine * mw * night * night * night * 0.4;
		}
	}
	// Mond: Scheibe mit Mare (dunkle Flecken), Kratern, Randverdunklung und Schattenseite
	vec3 md = normalize(moon_dir);
	float mdot = dot(d, md);
	float ang = acos(clamp(mdot, -1.0, 1.0));
	float near_horizon = 1.0 - smoothstep(0.0, 0.35, md.y);
	vec3 mtint = mix(moon_tint, vec3(1.0, 0.62, 0.35), near_horizon * 0.85);
	if (moon_vis > 0.001) {
		if (ang < moon_size && !AT_CUBEMAP_PASS) {
			vec3 up = abs(md.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
			vec3 tx = normalize(cross(up, md));
			vec3 ty = cross(md, tx);
			vec2 uv = vec2(dot(d - md, tx), dot(d - md, ty)) / moon_size;
			float r2 = dot(uv, uv);
			float z = sqrt(max(0.0, 1.0 - r2));
			vec3 n = normalize(tx * uv.x + ty * uv.y + md * z);
			float mare = texture(cloud_noise, uv * 0.45 + vec2(0.21, 0.63)).r;
			float shade = mix(1.0, 0.62, smoothstep(0.45, 0.7, mare));
			// ein paar Krater: helle Ränder, dunkle Mitte
			for (int i = 0; i < 6; i++) {
				vec2 c = vec2(fract(sin(float(i) * 12.9) * 43.7), fract(sin(float(i) * 78.2) * 12.3)) * 1.4 - 0.7;
				float cr = 0.08 + fract(sin(float(i) * 3.3) * 9.1) * 0.12;
				float dd = length(uv - c);
				shade *= 1.0 - 0.25 * smoothstep(cr, cr * 0.6, dd) + 0.15 * smoothstep(cr * 1.15, cr, dd) * smoothstep(cr * 0.85, cr, dd);
			}
			float limb = mix(0.55, 1.0, pow(z, 0.5));
			// Schattenseite (abnehmender Mond): von der Seite beleuchtet
			float lit = smoothstep(-0.15, 0.25, dot(n, normalize(md + tx * moon_phase * 1.8)) - (1.0 - z) * 0.2);
			float edge = smoothstep(1.0, 0.92, sqrt(r2));
			vec3 disc = mtint * shade * limb * mix(0.04, 1.0, lit) * 1.6;
			col = mix(col, disc + col * 0.2, edge * moon_vis);
		}
		// Lichtsaum und Mondhof (bei dünnen Wolken ein Ring)
		float glow = exp(-(ang - moon_size) * 22.0) * 0.18 + exp(-ang * 4.0) * 0.06;
		col += mtint * max(glow, 0.0) * moon_vis * (ang > moon_size ? 1.0 : 0.0);
		float ring = exp(-pow((ang - 0.38) * 18.0, 2.0)) * 0.05 * smoothstep(0.2, 0.6, clouds) * (1.0 - smoothstep(0.7, 0.95, clouds));
		col += vec3(0.8, 0.85, 1.0) * ring * moon_vis;
	}
	// Wolken: tags weiß/grau, nachts dunkel mit hellen Rändern nahe dem Mond; ziehen mit dem Wind
	float c = cloud_at(d);
	if (c > 0.001) {
		float moon_light = exp(-ang * 2.5) * moon_vis;
		vec3 cn = mix(vec3(0.015, 0.018, 0.025), vec3(0.25, 0.28, 0.36) * mtint, moon_light);
		vec3 cday = mix(cloud_day, cloud_day * 0.55, clouds * 0.7) * (0.6 + 0.4 * max(dot(d, normalize(sun_dir)), 0.0));
		vec3 ccol = mix(cday * energy, cn, night);
		ccol += sun_color * pow(max(sd, 0.0), 12.0) * 0.4 * sun_vis * (1.0 - night);
		col = mix(col, ccol, c * 0.92);
	}
	// Blitz: hellt Wolken und Himmel in seiner Richtung auf
	if (flash > 0.001) {
		float fd = max(dot(d, normalize(flash_dir)), 0.0);
		col += vec3(0.7, 0.75, 1.0) * flash * (0.25 + pow(fd, 6.0) * 2.0) * (0.3 + c);
	}
	COLOR = col;
}
