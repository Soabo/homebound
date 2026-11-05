class_name DayNightEnvironment
extends Node3D
## Licht, Himmel und Nebel abhängig von der Uhrzeit des Time Managers.
## Nachts soll es wirklich dunkel sein – Taschenlampe, Kamin und Lampen
## sind dann die einzigen Lichtquellen (GDD 2.3 / 18.4).

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial

const NIGHT_TOP := Color(0.004, 0.006, 0.012)
const NIGHT_HORIZON := Color(0.012, 0.016, 0.028)
const DAY_TOP := Color(0.24, 0.42, 0.7)
const DAY_HORIZON := Color(0.66, 0.72, 0.78)
const SUNSET_HORIZON := Color(0.9, 0.48, 0.26)

var _indoor: float = 0.0


func _player_indoors() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player != null and Cabin.is_inside(player.global_position)


func _ready() -> void:
	name = "DayNightEnvironment"
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat

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
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_sky_affect = 0.0
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
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	add_child(moon)

	_apply(TimeManager.hour)


func _process(_delta: float) -> void:
	_apply(TimeManager.hour)


## Sonnenhöhe in Grad: 0 kurz nach 7 Uhr und kurz vor 19 Uhr, Höchststand um 13 Uhr.
static func sun_altitude_deg(h: float) -> float:
	return sin(TAU * (h - 7.0) / 24.0) * 58.0 - 2.0


func _apply(h: float) -> void:
	var alt := sun_altitude_deg(h)
	var az := (13.0 - h) * 12.0
	sun.rotation_degrees = Vector3(-maxf(alt, 0.5), az, 0.0)

	var day := smoothstep(-9.0, 12.0, alt)
	var sun_strength := smoothstep(-1.0, 9.0, alt)
	var low_sun := clampf(1.0 - absf(alt - 3.0) / 14.0, 0.0, 1.0) * smoothstep(-6.0, 0.0, alt)

	sun.visible = sun_strength > 0.001
	sun.light_energy = sun_strength * 1.25
	sun.light_color = Color(1.0, 0.55, 0.32).lerp(Color(1.0, 0.96, 0.9), smoothstep(2.0, 22.0, alt))

	var night := 1.0 - day
	# Erste Nachthälfte stockfinster; ab etwa 1 Uhr geht der Mond auf und spendet ein ganz schwaches Licht,
	# gerade genug für grobe Umrisse. Er steigt bis zum Morgen langsam höher.
	var mh := TimeManager.hour if TimeManager.hour < 12.0 else TimeManager.hour - 24.0
	var moon_up := smoothstep(0.5, 3.0, mh) * night
	moon.visible = moon_up > 0.01
	moon.light_energy = moon_up * 0.11
	moon.rotation_degrees = Vector3(-lerpf(4.0, 34.0, clampf((mh - 0.5) / 6.0, 0.0, 1.0)), 105.0 + clampf(mh, 0.0, 7.0) * 6.0, 0.0)

	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day).lerp(SUNSET_HORIZON, low_sun * 0.75)
	sky_mat.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, day)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.25)
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.03).lerp(Color(0.15, 0.14, 0.12), day)
	sky_mat.sky_energy_multiplier = lerpf(lerpf(0.1, 0.3, moon_up), 1.0, day)

	# Ohne Global Illumination würde das Himmelslicht auch drinnen alles
	# bläulich aufhellen – deshalb in Innenräumen deutlich weniger Umgebungslicht.
	var target_indoor := 1.0 if _player_indoors() else 0.0
	_indoor = move_toward(_indoor, target_indoor, get_process_delta_time() * 1.5)
	env.ambient_light_energy = lerpf(lerpf(0.02, 0.05, moon_up), 0.6, day) * lerpf(1.0, 0.85, _indoor)
	# Grundlicht in der Hütte folgt dem Tageslicht – nachts bleibt es drinnen dunkel.
	for probe in get_tree().get_nodes_in_group("interior_probe"):
		(probe as ReflectionProbe).ambient_color_energy = lerpf(0.03, 1.0, day)
	env.ambient_light_color = Color(0.05, 0.06, 0.09).lerp(Color(0.55, 0.52, 0.46), day)
	env.background_energy_multiplier = lerpf(lerpf(0.12, 0.35, moon_up), 1.0, day)
	env.fog_light_color = Color(0.015, 0.02, 0.03).lerp(Color(0.62, 0.68, 0.74), day).lerp(SUNSET_HORIZON * 0.7, low_sun * 0.4)
	# Terraforming ab Stufe 2: nachts dichterer Nebel
	var fog_mult := 1.0 + (0.9 if WorldState.stage() >= 2 else 0.0) * (1.0 - day)
	env.fog_density = lerpf(0.016, 0.004, day) * fog_mult
	env.volumetric_fog_density = lerpf(0.035, 0.008, day) * fog_mult
	env.volumetric_fog_albedo = Color(0.5, 0.55, 0.62).lerp(Color(0.85, 0.87, 0.9), day)
	env.adjustment_saturation = lerpf(0.65, 1.05, day)
