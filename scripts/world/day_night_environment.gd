class_name DayNightEnvironment
extends Node3D
## Licht, Himmel und Nebel abhängig von Uhrzeit (Time Manager) und Wetter (WorldState.weather).
## Nachts soll es wirklich dunkel sein – Taschenlampe, Kamin und Lampen sind dann die einzigen
## Lichtquellen (GDD 2.3 / 18.4). Ab etwa 1 Uhr geht der Mond auf: groß, erst orange am Horizont,
## dann weiß, mit Kratern, Lichtsaum und Mondhof; Wolken ziehen vor ihm vorbei und dämpfen sein Licht.
## Dazu: Sterne und Milchstraße, Lichtstrahlen durch die Kronen (Volumennebel), Bodennebel morgens und
## abends, Nebeltage, Blitze im Gewitter, Wetterleuchten, Farbabstimmung je Tageszeit (RetroFilter.set_grade)
## und die Augen, die sich an hell/dunkel gewöhnen müssen (Belichtung beim Raus- und Reingehen).

static var current: DayNightEnvironment

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var bolt: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial

const NIGHT_TOP := Color(0.004, 0.006, 0.014)
const NIGHT_HORIZON := Color(0.012, 0.016, 0.03)
const DAY_TOP := Color(0.24, 0.42, 0.7)
const DAY_HORIZON := Color(0.66, 0.72, 0.78)
const SUNSET_HORIZON := Color(0.9, 0.48, 0.26)
const DAWN_HORIZON := Color(0.85, 0.6, 0.62)

var _indoor: float = 0.0
var _weather_mix: Dictionary = {"clear": 1.0}   ## weich überblendete Wetter-Anteile
var _flash: float = 0.0
var _flash_dir := Vector3(1, 0.3, 0)
var _adapt: float = 1.0          ## Augen-Anpassung: Faktor auf die Belichtung
var _was_indoor: bool = false
var _cloud_img: Image
var _wind_time: float = 0.0
## Wie viel vom Mond gerade frei ist (0 = hinter Wolken), für Licht und Tests
var moon_clear: float = 1.0
var moon_visible: float = 0.0


func _player_indoors() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player != null and (Cabin.is_inside(player.global_position) or Shed.is_inside(player.global_position))


func _ready() -> void:
	name = "DayNightEnvironment"
	current = self
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	noise.seed = 11
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.generate_mipmaps = true
	_cloud_img = noise.get_seamless_image(256, 256)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("cloud_noise", tex)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_sky_affect = 0.7
	env.fog_height = 1.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_anisotropy = 0.6   # Licht streut nach vorn: Strahlen gegen die Sonne
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.adjustment_enabled = true

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_blur = 1.5
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	add_child(moon)

	# Blitzlicht: nur für einen Wimpernschlag, ohne Schatten
	bolt = DirectionalLight3D.new()
	bolt.name = "Lightning"
	bolt.shadow_enabled = false
	bolt.light_color = Color(0.8, 0.85, 1.0)
	bolt.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	bolt.visible = false
	add_child(bolt)

	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_apply(TimeManager.hour, 0.0)


func _exit_tree() -> void:
	if current == self:
		current = null


## Einstellungen: Helligkeit und Grafikstufe (Umgebungsverdeckung, Volumennebel).
func _apply_settings() -> void:
	var q := Settings.quality_values()
	env.ssao_enabled = bool(q.get("ssao", true))
	env.volumetric_fog_enabled = bool(q.get("volumetric", true))


func _process(delta: float) -> void:
	_apply(TimeManager.hour, delta)


## Blitz (WeatherFx): Himmel und Welt hellen für einen Moment auf.
func flash(strength: float, dir: Vector3) -> void:
	_flash = maxf(_flash, strength)
	_flash_dir = dir.normalized()


## Sonnenhöhe in Grad: 0 kurz nach 7 Uhr und kurz vor 19 Uhr, Höchststand um 13 Uhr.
static func sun_altitude_deg(h: float) -> float:
	return sin(TAU * (h - 7.0) / 24.0) * 58.0 - 2.0


func _w(kind: String) -> float:
	return float(_weather_mix.get(kind, 0.0))


func _apply(h: float, delta: float) -> void:
	# Wetter weich überblenden (ca. 1 Minute)
	var target_kind := WorldState.weather
	for k: String in ["clear", "cloudy", "rain", "fog", "storm"]:
		var goal := 1.0 if k == target_kind else 0.0
		_weather_mix[k] = move_toward(_w(k), goal, delta / 60.0) if delta > 0.0 else goal
	var clouds := 0.0
	for k: String in _weather_mix:
		clouds += _w(k) * float(WorldState.config.get("clouds_" + k))
	var rainy := _w("rain") + _w("storm")
	var foggy := _w("fog")

	var alt := sun_altitude_deg(h)
	var az := (13.0 - h) * 12.0
	sun.rotation_degrees = Vector3(-maxf(alt, 0.5), az, 0.0)

	var day := smoothstep(-9.0, 12.0, alt)
	var sun_strength := smoothstep(-1.0, 9.0, alt) * (1.0 - clouds * 0.75) * (1.0 - rainy * 0.55) * (1.0 - foggy * 0.4)
	var low_sun := clampf(1.0 - absf(alt - 3.0) / 14.0, 0.0, 1.0) * smoothstep(-6.0, 0.0, alt)
	var morning := 1.0 if h < 12.0 else 0.0

	sun.visible = sun_strength > 0.001
	sun.light_energy = sun_strength * 1.25
	# Abend golden, Morgen kühl-rosa, mittags fast weiß
	var low_col := Color(1.0, 0.72, 0.62).lerp(Color(1.0, 0.55, 0.3), 1.0 - morning)
	sun.light_color = low_col.lerp(Color(1.0, 0.96, 0.9), smoothstep(2.0, 22.0, alt))
	# Lichtstrahlen durch die Kronen: tief stehende Sonne streut stärker im Nebel
	sun.light_volumetric_fog_energy = lerpf(1.0, 3.2, low_sun) * (1.0 - clouds * 0.6)

	var night := 1.0 - day
	# Erste Nachthälfte stockfinster; ab etwa 1 Uhr geht der Mond auf. Er steigt bis zum Morgen langsam höher.
	var mh := TimeManager.hour if TimeManager.hour < 12.0 else TimeManager.hour - 24.0
	var moon_up := smoothstep(0.5, 3.0, mh) * night
	var moon_rot := Vector3(-lerpf(3.0, 40.0, clampf((mh - 0.5) / 4.0, 0.0, 1.0)), 105.0 + clampf(mh, 0.0, 7.0) * 6.0, 0.0)
	moon.rotation_degrees = moon_rot
	var moon_dir := moon.global_transform.basis.z
	# Mondphase wandert langsam über die Tage (meist fast voll)
	var phase := 0.08 + 0.5 * absf(sin(float(TimeManager.day) * PI / 15.0))
	moon_clear = 1.0 - _cloud_cover(moon_dir) * 0.9
	moon_visible = smoothstep(0.0, 1.5, mh) * night
	moon.visible = moon_up > 0.01
	moon.light_energy = moon_up * lerpf(0.12, 0.3, smoothstep(5.0, 30.0, -moon_rot.x)) * moon_clear * (1.0 - phase * 0.5) * (1.0 - foggy * 0.6)

	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day).lerp(SUNSET_HORIZON if morning < 0.5 else DAWN_HORIZON, low_sun * 0.75 * (1.0 - clouds * 0.6))
	var grey := Color(0.5, 0.52, 0.55)
	var top := NIGHT_TOP.lerp(DAY_TOP.lerp(grey * 0.85, clouds * 0.8), day)
	horizon = horizon.lerp(horizon.lerp(grey, 0.7), clouds * day)
	var sky_energy := lerpf(lerpf(0.1, 0.25, moon_up), 1.0 - rainy * 0.3, day)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("ground_horizon", horizon.darkened(0.25))
	sky_mat.set_shader_parameter("ground_bottom", Color(0.03, 0.03, 0.03).lerp(Color(0.15, 0.14, 0.12), day))
	sky_mat.set_shader_parameter("energy", sky_energy)
	sky_mat.set_shader_parameter("sun_dir", sun.global_transform.basis.z)
	sky_mat.set_shader_parameter("sun_color", sun.light_color)
	sky_mat.set_shader_parameter("sun_vis", smoothstep(-3.0, 2.0, alt) * (1.0 - clouds * 0.8))
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("moon_vis", moon_visible)
	sky_mat.set_shader_parameter("moon_phase", phase)
	sky_mat.set_shader_parameter("night", night * (1.0 - foggy * 0.85))
	sky_mat.set_shader_parameter("clouds", clouds)
	sky_mat.set_shader_parameter("alien", clampf(float(WorldState.stage()) / 4.0, 0.0, 1.0))

	# Blitz klingt schnell ab
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	sky_mat.set_shader_parameter("flash", _flash)
	sky_mat.set_shader_parameter("flash_dir", _flash_dir)
	bolt.visible = _flash > 0.02
	bolt.light_energy = _flash * 1.6
	bolt.rotation = Vector3(-0.9, atan2(_flash_dir.x, _flash_dir.z) + PI, 0.0)

	# Ohne Global Illumination würde das Himmelslicht auch drinnen alles
	# bläulich aufhellen – deshalb in Innenräumen deutlich weniger Umgebungslicht.
	var indoor := _player_indoors()
	var target_indoor := 1.0 if indoor else 0.0
	_indoor = move_toward(_indoor, target_indoor, delta * 1.5)
	env.ambient_light_energy = lerpf(lerpf(0.02, 0.07, moon_up * moon_clear), 0.6 - clouds * 0.15, day) * lerpf(1.0, 0.85, _indoor) + _flash * 0.4
	# Grundlicht in der Hütte folgt dem Tageslicht – nachts bleibt es drinnen dunkel.
	for probe in get_tree().get_nodes_in_group("interior_probe"):
		(probe as ReflectionProbe).ambient_color_energy = lerpf(0.03, 1.0, day) * (1.0 - clouds * 0.3)
	env.ambient_light_color = Color(0.05, 0.06, 0.09).lerp(Color(0.55, 0.52, 0.46), day)
	env.background_energy_multiplier = 1.0
	env.fog_light_color = Color(0.015, 0.02, 0.03).lerp(Color(0.62, 0.68, 0.74).lerp(grey, clouds * 0.5), day).lerp(SUNSET_HORIZON * 0.7, low_sun * 0.4)

	# Nebel: Terraforming ab Stufe 2 nachts dichter, Nebeltage (~30 m Sicht), Regen leicht diesig,
	# Bodennebel in den Morgen- und Abendstunden (liegt unten in Senken und über dem Bach)
	var fog_mult := 1.0 + (0.9 if WorldState.stage() >= 2 else 0.0) * (1.0 - day)
	var ground_fog := maxf(1.0 - absf(h - 6.5) / 2.2, 0.0) + maxf(1.0 - absf(h - 19.5) / 1.8, 0.0) * 0.7
	env.fog_density = (lerpf(0.016, 0.004, day) + foggy * 0.05 + rainy * 0.008) * fog_mult
	env.fog_height_density = ground_fog * 0.35 + foggy * 0.2
	env.volumetric_fog_density = (lerpf(0.035, 0.012, day) + ground_fog * 0.02 + foggy * 0.06 + rainy * 0.01) * fog_mult
	env.volumetric_fog_albedo = Color(0.5, 0.55, 0.62).lerp(Color(0.85, 0.87, 0.9), day)

	# Farbabstimmung je Tageszeit: mittags klar, abends golden, morgens kühl, nachts kalt blau,
	# bei fremder Nähe/Terraforming ein leicht kranker Grünstich
	var alien := clampf(float(WorldState.stage()) * 0.06 + _alien_near() * 0.25, 0.0, 0.5)
	var tint := Color(1.0, 1.0, 1.0)
	tint = tint.lerp(Color(1.08, 0.97, 0.85) if morning < 0.5 else Color(0.98, 0.98, 1.06), low_sun)
	tint = tint.lerp(Color(0.82, 0.92, 1.12), night)
	tint = tint.lerp(Color(0.93, 0.96, 1.0), clouds * day * 0.6)
	tint = tint.lerp(Color(0.9, 1.08, 0.88), alien)
	var lift := Color(0.0, 0.004, 0.012).lerp(Color(0.012, 0.008, 0.0), day)
	var sat := lerpf(0.65, 1.05, day) * (1.0 - clouds * 0.15 * day) * (1.0 - alien * 0.3)
	var contrast := lerpf(1.08, 1.0, day) + low_sun * 0.04
	env.adjustment_saturation = 1.0
	for f in get_tree().get_nodes_in_group("retro_filter"):
		f.call("set_grade", tint, lift, sat, contrast)

	# Augen-Anpassung: aus dem dunklen Haus in die Sonne blendet es kurz, aus dem Hellen ins Dunkle sieht man erst wenig
	if indoor != _was_indoor and delta > 0.0:
		if not indoor and day > 0.6:
			_adapt = 2.1
		elif indoor and day > 0.6:
			_adapt = 0.55
		_was_indoor = indoor
	_adapt = move_toward(_adapt, 1.0, delta * 0.9)
	env.tonemap_exposure = Settings.brightness * _adapt


## Wie dicht die Wolken in einer Himmelsrichtung sind (0..1) – dieselbe Rechnung wie im Himmels-Shader.
func _cloud_cover(d: Vector3) -> float:
	if d.y <= 0.0 or _cloud_img == null:
		return 0.0
	var clouds := float(sky_mat.get_shader_parameter("clouds")) if sky_mat.get_shader_parameter("clouds") != null else 0.3
	var wd := Wind.current.dir if Wind.current else Vector2(0.8, 0.6)
	var wt := Wind.current.time if Wind.current else 0.0
	var uv := Vector2(d.x, d.z) / (d.y + 0.12) * 0.22 + wd * wt * 0.004
	var n := _sample(uv) * 0.65 + _sample(uv * 2.7 + Vector2(0.3, 0.7)) * 0.35
	return smoothstep(1.0 - clouds * 0.95, 1.05 - clouds * 0.55, n + clouds * 0.25) * smoothstep(0.0, 0.12, d.y)


func _sample(uv: Vector2) -> float:
	var x := int(fposmod(uv.x, 1.0) * 256.0) % 256
	var y := int(fposmod(uv.y, 1.0) * 256.0) % 256
	return _cloud_img.get_pixel(x, y).r


## Ist etwas Fremdes in der Nähe? (0..1) – für den Grünstich.
func _alien_near() -> float:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return 0.0
	var best := 0.0
	for g: String in ["creature", "mauler", "seeker"]:
		for n in get_tree().get_nodes_in_group(g):
			var d := (n as Node3D).global_position.distance_to(p.global_position)
			best = maxf(best, 1.0 - smoothstep(10.0, 45.0, d))
	return best
