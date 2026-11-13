class_name AirFx
extends Node3D
## Kleine Teilchen in der Luft um den Spieler – damit die Welt atmet:
##  Pollen und Schwebstaub am Tag (glitzern im Sonnenlicht), Mückenschwärme am Bach,
##  Glühwürmchen in ruhigen Nächten, fallende Blätter bei Wind, sichtbarer Atem in kalten Nächten.
## Alles folgt der Kamera, ist billig (CPU-Teilchen) und schaltet sich je nach Tageszeit, Wetter und Ort ein.

var _motes: CPUParticles3D
var _gnats: CPUParticles3D
var _flies: CPUParticles3D
var _leaves: CPUParticles3D
var _breath: CPUParticles3D
var _mist: CPUParticles3D
var _breath_t: float = 2.0
var _player: Player
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "AirFx"
	_rng.randomize()
	_motes = _particles("Motes", 120, 9.0, Vector3(9, 4, 9), Color(1.0, 0.97, 0.85), 0.018, true)
	_motes.initial_velocity_max = 0.08
	_motes.gravity = Vector3(0, -0.01, 0)
	_gnats = _particles("Gnats", 40, 2.5, Vector3(0.7, 0.5, 0.7), Color(0.08, 0.08, 0.07), 0.012, true)
	_gnats.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_gnats.emission_sphere_radius = 0.7
	_gnats.orbit_velocity_min = 0.6
	_gnats.orbit_velocity_max = 1.2
	_gnats.initial_velocity_max = 0.6
	_gnats.gravity = Vector3.ZERO
	_gnats.local_coords = true
	_flies = _particles("Fireflies", 45, 6.0, Vector3(14, 1.6, 14), Color(0.75, 1.0, 0.35), 0.035, false)
	_flies.initial_velocity_max = 0.15
	_flies.gravity = Vector3(0, 0.01, 0)
	var blink := Gradient.new()
	blink.offsets = PackedFloat32Array([0.0, 0.15, 0.25, 0.5, 0.6, 0.72, 1.0])
	blink.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0),
		Color(1, 1, 1, 0.9), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	_flies.color_ramp = blink
	_leaves = _particles("Leaves", 50, 7.0, Vector3(10, 1, 10), Color(1, 1, 1), 0.07, true)
	_leaves.gravity = Vector3(0, -0.6, 0)
	_leaves.angular_velocity_min = -180.0
	_leaves.angular_velocity_max = 180.0
	_leaves.damping_min = 0.4
	_leaves.damping_max = 0.9
	var lc := Gradient.new()
	lc.colors = PackedColorArray([Color(0.62, 0.42, 0.14), Color(0.48, 0.28, 0.1), Color(0.7, 0.6, 0.2)])
	lc.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_leaves.color_initial_ramp = lc
	(_leaves.mesh.surface_get_material(0) as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_breath = _particles("Breath", 10, 1.6, Vector3(0.03, 0.03, 0.03), Color(0.9, 0.92, 0.95, 0.22), 0.09, true)
	_breath.one_shot = true
	_breath.explosiveness = 0.7
	_breath.initial_velocity_min = 0.25
	_breath.initial_velocity_max = 0.5
	_breath.direction = Vector3(0, 0.3, -1)
	_breath.spread = 18.0
	_breath.gravity = Vector3(0, 0.05, 0)
	_breath.scale_amount_min = 0.6
	_breath.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	_breath.color_ramp = fade
	_breath.local_coords = false
	# Dunst über dem Wasser: morgens und abends, flache, langsam treibende Schwaden
	_mist = _particles("WaterMist", 36, 14.0, Vector3(5, 0.25, 9), Color(0.85, 0.88, 0.92, 0.12), 2.6, true)
	_mist.initial_velocity_max = 0.12
	_mist.gravity = Vector3(0, 0.004, 0)
	_mist.scale_amount_min = 0.7
	_mist.scale_amount_max = 1.8
	var mf := Gradient.new()
	mf.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	mf.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	_mist.color_ramp = mf
	var mm := _mist.mesh.surface_get_material(0) as StandardMaterial3D
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.proximity_fade_enabled = true
	mm.proximity_fade_distance = 1.2
	mm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mm.distance_fade_min_distance = 0.5
	mm.distance_fade_max_distance = 4.0
	mm.albedo_texture = _soft_dot()


func _soft_dot() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2.0))
	return ImageTexture.create_from_image(img)


func _particles(n: String, amount: int, life: float, box: Vector3, col: Color, size: float, shaded: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.1
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.roughness = 1.0
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not shaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.5
	q.material = m
	p.mesh = q
	add_child(p)
	return p


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var cam := _player.camera.global_transform
	var pp := _player.global_position
	var outside := not Cabin.is_inside(pp) and not Shed.is_inside(pp)
	var h := TimeManager.hour
	var night := TimeManager.is_night()
	var w := WorldState.weather
	var dry := w != "rain" and w != "storm"
	var wind := Wind.current
	var ws := wind.at(pp) if wind else 0.2
	var wdir := Vector3(wind.dir.x, 0, wind.dir.y) if wind else Vector3(1, 0, 0)
	# Pollen und Schwebstaub: helle Tagesstunden, trocken, draußen
	_motes.global_position = cam.origin + (-cam.basis.z) * 3.0
	_motes.emitting = outside and not night and dry and w != "fog" and h > 8.0 and h < 19.5
	_motes.gravity = Vector3(wdir.x, -0.01, wdir.z) * 0.05 * ws
	# Mücken: über dem Bach an warmen Nachmittagen
	var at_stream := Terrain.stream_distance(pp.x, pp.z) < 12.0
	if at_stream and not _gnats.emitting and outside and not night and dry and h > 12.0 and h < 20.0 and ws < 0.5:
		_gnats.global_position = pp + Vector3(_rng.randf_range(-3, 3), 1.4, _rng.randf_range(-3, 3))
		_gnats.emitting = true
	elif not at_stream or night or not dry or ws >= 0.5:
		_gnats.emitting = false
	if _gnats.emitting and _gnats.global_position.distance_to(pp) > 18.0:
		_gnats.global_position = pp + Vector3(_rng.randf_range(-4, 4), 1.4, _rng.randf_range(-4, 4))
	# Glühwürmchen: ruhige, trockene Nächte, nicht wenn etwas Fremdes nah ist oder das Tal schon kippt
	var calm := ws < 0.35 and dry and WorldState.stage() < 2 and get_tree().get_nodes_in_group("mauler").is_empty() \
		and get_tree().get_nodes_in_group("creature").is_empty()
	_flies.global_position = Vector3(pp.x, pp.y + 1.0, pp.z)
	_flies.emitting = outside and night and calm and (h > 21.0 or h < 1.0)
	# Fallende Blätter: bei Wind, draußen im Wald
	_leaves.global_position = cam.origin + Vector3(0, 5, 0) - wdir * 3.0
	_leaves.gravity = Vector3(0, -0.6, 0) + wdir * ws * 1.6
	_leaves.emitting = outside and ws > 0.3 and Vector2(pp.x, pp.z).length() > 22.0
	# Atem: kalte Nächte, Kälte, Höhe
	_breath_t -= delta
	var cold := outside and (night or Survival.warmth < 55.0 or pp.y > 120.0 or w == "fog")
	if cold and _breath_t <= 0.0:
		_breath_t = _rng.randf_range(3.2, 4.6) * (0.6 if Input.is_action_pressed("sprint") else 1.0)
		_breath.global_position = cam.origin + (-cam.basis.z) * 0.32 - cam.basis.y * 0.12
		_breath.direction = -cam.basis.z + Vector3(0, 0.3, 0)
		_breath.restart()
	# Dunst über dem Bach: Dämmerung, ruhiger Wind, nahe am Wasser
	var sd := Terrain.stream_distance(pp.x, pp.z)
	var misty_hour := (h > 4.5 and h < 9.0) or (h > 18.5 and h < 21.5) or w == "fog"
	_mist.emitting = outside and misty_hour and sd < 40.0 and ws < 0.6
	if _mist.emitting:
		# Schwaden liegen über dem Bachlauf auf Höhe des Spielers (z), nicht beim Spieler selbst
		var sx := Terrain.stream_x_at(pp.z)
		var wl := Terrain.water_level_at(sx, pp.z)
		_mist.global_position = Vector3(sx, wl + 0.35, pp.z)
		_mist.gravity = Vector3(wdir.x * ws * 0.03, 0.004, wdir.z * ws * 0.03)
