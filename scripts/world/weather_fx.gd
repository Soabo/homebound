class_name WeatherFx
extends Node3D
## Was man vom Wetter (WorldState.weather) sieht und hört:
##  Regen (Fäden um die Kamera, Rauschen draußen, Prasseln aufs Dach drinnen), nach dem Regen Tropfen von den
##  Blättern, Gewitter mit Blitz und Donner (je weiter weg, desto später und leiser), Wetterleuchten in klaren
##  Nächten ganz fern am Horizont (ohne Donner). Draußen im Regen wird man nass (Survival.set_wet).
## Werte: WorldConfig (weather_*, lightning_seconds, heat_lightning_chance, rain_wets).

var _rain: CPUParticles3D
var _drops: CPUParticles3D
var _rain_snd: AudioStreamPlayer
var _roof_snd: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _next_bolt: float = 10.0
var _heat_t: float = 0.0
var _wet_t: float = 0.0
var _rain_amount: float = 0.0
var _player: Player


func _ready() -> void:
	name = "WeatherFx"
	_rng.randomize()
	_rain = _make_rain()
	add_child(_rain)
	_drops = _make_drops()
	add_child(_drops)
	_rain_snd = _loop("rain", -60.0)
	_roof_snd = _loop("rain_roof", -60.0)


func _loop(id: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = SoundBank.get_sound(id) if SoundBank.has_recording(id) else SoundBank.get_generated(id)
	p.volume_db = db
	add_child(p)
	return p


func _make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Rain"
	p.amount = 1600
	p.lifetime = 1.0
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 0.5, 14)
	p.direction = Vector3(0, -1, 0)
	p.spread = 4.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 19.0
	p.gravity = Vector3(0, -6, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.45)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.28)
	q.material = m
	p.mesh = q
	return p


## Nach dem Regen: einzelne große Tropfen fallen aus den Kronen.
func _make_drops() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "LeafDrops"
	p.amount = 60
	p.lifetime = 1.4
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9, 1.5, 9)
	p.direction = Vector3(0, -1, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -9.8, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.07)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.8, 0.85, 0.95, 0.45)
	q.material = m
	p.mesh = q
	return p


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var cfg := WorldState.config
	var w := WorldState.weather
	var target := 1.0 if w == "storm" else (0.6 if w == "rain" else 0.0)
	_rain_amount = move_toward(_rain_amount, target, delta / 20.0)
	var cam := _player.camera.global_position
	var indoor := Cabin.is_inside(_player.global_position) or Shed.is_inside(_player.global_position)
	var tent := _player.in_tent != null
	# Regen um die Kamera (drinnen nicht – das Dach hält ihn ab)
	var wind := Wind.current
	_rain.global_position = cam + Vector3(0, 11, 0) - (Vector3(wind.dir.x, 0, wind.dir.y) * wind.strength * 5.0 if wind else Vector3.ZERO)
	_rain.emitting = _rain_amount > 0.05 and not indoor
	((_rain.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a = 0.3 * clampf(_rain_amount * 1.4, 0.15, 1.0)
	if wind:
		_rain.direction = Vector3(wind.dir.x * wind.strength * 0.35, -1, wind.dir.y * wind.strength * 0.35)
	# Tropfen aus den Bäumen, solange es nass ist und nicht mehr regnet
	_drops.global_position = cam + Vector3(0, 4, 0)
	_drops.emitting = WorldState.wetness > 0.3 and _rain_amount < 0.1 and not indoor and Vector2(cam.x, cam.z).length() > 25.0
	# Klang: draußen Rauschen, drinnen dumpfes Prasseln aufs Dach, im Zelt laut auf der Plane
	var loud := linear_to_db(maxf(_rain_amount, 0.0001))
	_set_vol(_rain_snd, loud - (4.0 if not indoor else 30.0) + (4.0 if tent else 0.0), delta)
	_set_vol(_roof_snd, loud - (2.0 if indoor else 40.0), delta)
	# nass werden
	if cfg.rain_wets and _rain_amount > 0.3 and not indoor and not tent:
		_wet_t -= delta
		if _wet_t <= 0.0:
			_wet_t = 5.0
			Survival.set_wet()
	_lightning(delta, w, cfg)


func _set_vol(p: AudioStreamPlayer, db: float, delta: float) -> void:
	p.volume_db = lerpf(p.volume_db, clampf(db, -60.0, 6.0), clampf(delta * 1.5, 0.0, 1.0))
	if p.volume_db > -55.0 and not p.playing:
		p.play()
	elif p.volume_db <= -58.0 and p.playing:
		p.stop()


func _lightning(delta: float, w: String, cfg: WorldConfig) -> void:
	if w == "storm":
		_next_bolt -= delta
		if _next_bolt <= 0.0:
			_next_bolt = _rng.randf_range(cfg.lightning_seconds.x, cfg.lightning_seconds.y)
			strike(_rng.randf_range(0.3, 4.5))
		return
	# Wetterleuchten: klare, warme Nächte, ganz fern, kein Donner
	if w == "clear" and TimeManager.is_night():
		_heat_t += delta
		if _heat_t >= 1.0 / maxf(TimeManager.get_hours_per_second() * 60.0, 0.0001):   # einmal pro Spielminute würfeln
			_heat_t = 0.0
			if _rng.randf() < cfg.heat_lightning_chance:
				var a := _rng.randf() * TAU
				var dn := DayNightEnvironment.current
				if dn:
					dn.flash(_rng.randf_range(0.12, 0.25), Vector3(cos(a), 0.05, sin(a)))
					get_tree().create_timer(0.18).timeout.connect(func() -> void:
						if is_instance_valid(dn):
							dn.flash(_rng.randf_range(0.08, 0.18), Vector3(cos(a), 0.05, sin(a))))


## Ein Blitz; Donner folgt nach seconds Sekunden (≈ 340 m pro Sekunde Entfernung).
func strike(seconds: float) -> void:
	var dn := DayNightEnvironment.current
	var a := _rng.randf() * TAU
	var dir := Vector3(cos(a), _rng.randf_range(0.15, 0.6), sin(a))
	if dn:
		dn.flash(lerpf(1.0, 0.45, seconds / 4.5), dir)
		# Blitze flackern meist zwei-, dreimal
		for k in _rng.randi_range(1, 2):
			get_tree().create_timer(0.09 + k * 0.11).timeout.connect(func() -> void:
				if is_instance_valid(dn):
					dn.flash(_rng.randf_range(0.4, 0.8), dir))
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(self):
			SoundBank.play_ui(self, "thunder", lerpf(0.0, -12.0, seconds / 4.5), _rng.randf_range(0.8, 1.05)))
